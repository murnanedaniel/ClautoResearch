#!/bin/bash
# Stop hook: prevent Claude from stopping when autonomous work remains.
# Fires when Claude tries to end its turn. Blocks unless at a gate point
# (slides ready for review).
#
# Review modes (review_mode in state.yaml):
#   pi_direct    — PI reviews every gate directly. No postdoc, no self-review.
#   self_review  — Student self-reviews at gates, PI meets at cadence.
#   postdoc      — Postdoc subagent reviews at gates, PI meets at cadence.
#   autonomous   — Postdoc reviews at all gates, never stops for PI.
#
# Gate points:
#   1. step=0, Monday slides exist
#   2. step=2, Wednesday slides exist
#
# Safety: uses stop_hook_active + counter file to prevent infinite loops.
# After 3 consecutive blocks at the same step, allows the stop.

set -euo pipefail

INPUT=$(cat)

# --- Parse hook input (grep-based, no jq dependency) ---
STOP_HOOK_ACTIVE="false"
if echo "$INPUT" | grep -q '"stop_hook_active" *: *true'; then
    STOP_HOOK_ACTIVE="true"
fi

SESSION_ID=$(echo "$INPUT" | grep -o '"session_id" *: *"[^"]*"' | sed 's/.*: *"//;s/"//')
SESSION_ID="${SESSION_ID:-unknown}"

# --- Find active project ---
PROJECTS_DIR="$CLAUDE_PROJECT_DIR/projects"
if [ ! -d "$PROJECTS_DIR" ]; then
    exit 0  # No projects — allow stop
fi

STATE_FILE=$(find "$PROJECTS_DIR" -name "state.yaml" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -z "$STATE_FILE" ]; then
    exit 0
fi

# --- Parse state.yaml ---
STEP=$(grep '^step:' "$STATE_FILE" | awk '{print $2}')
CYCLE=$(grep '^cycle:' "$STATE_FILE" | awk '{print $2}')
PHASE=$(grep '^phase:' "$STATE_FILE" | awk '{print $2}')
MODE=$(grep '^mode:' "$STATE_FILE" | awk '{print $2}')
MODE="${MODE:-working}"
REVIEW_MODE=$(grep '^review_mode:' "$STATE_FILE" | awk '{print $2}')
REVIEW_MODE="${REVIEW_MODE:-postdoc}"
SUPERVISOR_CADENCE=$(grep '^supervisor_cadence:' "$STATE_FILE" | awk '{print $2}')
SUPERVISOR_CADENCE="${SUPERVISOR_CADENCE:-4}"
ESCALATION=$(grep '^escalation:' "$STATE_FILE" | sed 's/^escalation: *//')
ESCALATION="${ESCALATION:-null}"

# Only enforce during R&D phase
if [ "$PHASE" != "rd" ]; then
    exit 0
fi

# In meeting mode, always allow stop (PI meeting in progress)
if [ "$MODE" = "meeting" ]; then
    rm -f "/tmp/clauto_stop_count_${SESSION_ID}"
    exit 0
fi

# --- Determine if this is a PI meeting cycle ---
# For pi_direct: every cycle is a PI meeting
# For autonomous: never a PI meeting (except cycle 1 planning, handled separately)
# For self_review/postdoc: cadence-based
IS_PI_MEETING=false
if [ "$REVIEW_MODE" = "pi_direct" ]; then
    IS_PI_MEETING=true
elif [ "$REVIEW_MODE" = "autonomous" ]; then
    IS_PI_MEETING=false
else
    # self_review or postdoc: cadence-based
    if [ "$CYCLE" -eq 1 ]; then
        IS_PI_MEETING=true
    elif [ "$ESCALATION" != "null" ] && [ "$ESCALATION" != "" ]; then
        IS_PI_MEETING=true
    elif [ "$SUPERVISOR_CADENCE" -gt 0 ] && [ $((CYCLE % SUPERVISOR_CADENCE)) -eq 0 ]; then
        IS_PI_MEETING=true
    fi
fi

# --- Check slides ---
PROJECT_DIR=$(dirname "$STATE_FILE")
CYCLE_DIR="$PROJECT_DIR/cycles/cycle_$(printf '%02d' "$CYCLE")"
SLIDES_DIR="$CYCLE_DIR/slides"
CYCLE_FMT=$(printf '%02d' "$CYCLE")

HAS_MONDAY=false
HAS_WEDNESDAY=false
if ls "$SLIDES_DIR"/cycle_*_monday.pdf >/dev/null 2>&1; then
    HAS_MONDAY=true
fi
if ls "$SLIDES_DIR"/cycle_*_wednesday.pdf >/dev/null 2>&1; then
    HAS_WEDNESDAY=true
fi

DIRECTION=$(grep '^direction:' "$STATE_FILE" | awk '{print $2}')
VELOCITY=$(grep '^velocity:' "$STATE_FILE" | awk '{print $2}')

# --- Helper: set mode in state.yaml ---
set_mode() {
    local NEW_MODE="$1"
    sed -i "s/^mode:.*/mode: ${NEW_MODE}/" "$STATE_FILE"
    if ! grep -q '^mode:' "$STATE_FILE"; then
        echo "mode: ${NEW_MODE}" >> "$STATE_FILE"
    fi
}

# --- Helper: emit block decision ---
block() {
    local REASON="$1"
    cat <<HOOK_EOF
{
  "decision": "block",
  "reason": "$REASON"
}
HOOK_EOF
    exit 0
}

# ================================================================
# GATE LOGIC: dispatches based on review_mode
# ================================================================

# --- Gate handler for pi_direct mode ---
handle_gate_pi_direct() {
    local GATE_TYPE="$1"  # monday or wednesday
    local NEXT_STEP="$2"  # step to advance to after meeting

    # Simple: set mode to meeting, allow stop
    set_mode "meeting"
    rm -f "/tmp/clauto_stop_count_${SESSION_ID}"
    exit 0
}

# --- Gate handler for self_review mode ---
handle_gate_self_review() {
    local GATE_TYPE="$1"
    local NEXT_STEP="$2"

    if [ "$MODE" = "self_review" ]; then
        # Self-review in progress — block until complete
        if [ "$IS_PI_MEETING" = true ]; then
            AFTER_MSG="After completing self-review: record your assessment in cycle notes under '## Gate Review', set mode to 'meeting' in state.yaml, then stop for PI meeting."
        else
            AFTER_MSG="After completing self-review: record your assessment in cycle notes under '## Gate Review', set mode to 'working' in state.yaml, advance step to ${NEXT_STEP}, and CONTINUE working (do NOT stop — this is not a PI meeting cycle)."
        fi
        block "SELF-REVIEW IN PROGRESS: Complete your self-review using the checklist from templates/self_review_prompt.md. Review your ${GATE_TYPE} slides against all criteria (methodology, scope, literature, results, alignment, presentation). ${AFTER_MSG}"
    else
        # First arrival at gate — enter self-review
        set_mode "self_review"

        if [ "$IS_PI_MEETING" = true ]; then
            FLOW_MSG="This is a PI MEETING CYCLE. After self-review, set mode to 'meeting' and stop — the PI will review."
        else
            FLOW_MSG="This is a NORMAL CYCLE. After self-review, record assessment, set mode to 'working', advance step to ${NEXT_STEP}, and CONTINUE working autonomously."
        fi

        block "$(echo "${GATE_TYPE}" | tr '[:lower:]' '[:upper:]') SLIDES READY — SELF-REVIEW REQUIRED: Read templates/self_review_prompt.md for the full checklist. Review your slides against all criteria. Be honest and thorough. ${FLOW_MSG}"
    fi
}

# --- Gate handler for postdoc mode ---
handle_gate_postdoc() {
    local GATE_TYPE="$1"
    local NEXT_STEP="$2"
    local SLIDE_FILE="${SLIDES_DIR}/cycle_${CYCLE_FMT}_${GATE_TYPE}.pdf"

    if [ "$MODE" = "postdoc_review" ]; then
        # Postdoc review in progress — block
        if [ "$IS_PI_MEETING" = true ]; then
            AFTER_MSG="When the postdoc returns APPROVED: record feedback in cycle notes under '## Gate Review', set mode to 'meeting' in state.yaml, then stop for PI meeting. The postdoc will also prepare a PI brief. If ESCALATE: same flow — set mode to 'meeting' and stop."
        else
            AFTER_MSG="When the postdoc returns APPROVED: record feedback in cycle notes under '## Gate Review', update direction/velocity per postdoc's adjustments in state.yaml, set mode to 'working', advance step to ${NEXT_STEP}, and CONTINUE working (do NOT stop — this is not a PI meeting cycle). If ESCALATE: set mode to 'meeting' in state.yaml and stop for an immediate PI meeting."
        fi
        block "POSTDOC REVIEW IN PROGRESS: Continue the review conversation with the postdoc subagent. Answer questions, provide requested data/plots. ${AFTER_MSG} If REVISIONS_REQUIRED: make changes, recompile slides, spawn a new postdoc review."
    else
        # First arrival at gate — enter postdoc review
        set_mode "postdoc_review"

        if [ "$IS_PI_MEETING" = true ]; then
            FLOW_MSG="This is a PI MEETING CYCLE. After the postdoc approves, set mode to 'meeting' and stop — the PI will review. Tell the postdoc this is a PI meeting cycle so they prepare a PI brief in .postdoc/pi_brief.md."
        else
            FLOW_MSG="This is a NORMAL CYCLE (postdoc-only). After the postdoc approves, record feedback, update direction/velocity, set mode to 'working', advance step to ${NEXT_STEP}, and CONTINUE working autonomously. Do NOT stop. However, if the postdoc returns ESCALATE, set mode to 'meeting' and stop for an immediate PI meeting."
        fi

        block "$(echo "${GATE_TYPE}" | tr '[:lower:]' '[:upper:]') SLIDES READY — POSTDOC REVIEW REQUIRED: Spawn a postdoc subagent using the Agent tool. Read templates/postdoc_prompt.md for the full system prompt. Provide artifact paths in your Agent prompt: slide PDF=${SLIDE_FILE}, notes=${CYCLE_DIR}/notes.md, results=${CYCLE_DIR}/results/, code=${CYCLE_DIR}/code/, plan=${PROJECT_DIR}/plan.md, project=${PROJECT_DIR}. Also tell the postdoc: cycle=${CYCLE}, check-in=${GATE_TYPE}, direction=${DIRECTION}, velocity=${VELOCITY}. ${FLOW_MSG} Drive the conversation faithfully — relay ALL postdoc requests, provide raw data not summaries. You must NEVER read .postdoc/ files."
    fi
}

# --- Gate handler for autonomous mode ---
handle_gate_autonomous() {
    local GATE_TYPE="$1"
    local NEXT_STEP="$2"
    local SLIDE_FILE="${SLIDES_DIR}/cycle_${CYCLE_FMT}_${GATE_TYPE}.pdf"

    if [ "$MODE" = "postdoc_review" ]; then
        # Postdoc review in progress — block
        block "POSTDOC REVIEW IN PROGRESS (autonomous mode): Continue the review conversation with the postdoc subagent. Answer questions, provide requested data/plots. When the postdoc returns APPROVED: record feedback in cycle notes under '## Gate Review', update direction/velocity per postdoc's adjustments in state.yaml, set mode to 'working', advance step to ${NEXT_STEP}, and CONTINUE working. In autonomous mode you NEVER stop for a PI meeting. If REVISIONS_REQUIRED: make changes, recompile slides, spawn a new postdoc review."
    else
        # First arrival at gate — enter postdoc review
        set_mode "postdoc_review"

        block "$(echo "${GATE_TYPE}" | tr '[:lower:]' '[:upper:]') SLIDES READY — POSTDOC REVIEW (autonomous mode): Spawn a postdoc subagent using the Agent tool. Read templates/postdoc_prompt.md for the full system prompt. Provide artifact paths: slide PDF=${SLIDE_FILE}, notes=${CYCLE_DIR}/notes.md, results=${CYCLE_DIR}/results/, code=${CYCLE_DIR}/code/, plan=${PROJECT_DIR}/plan.md, project=${PROJECT_DIR}. Also tell the postdoc: cycle=${CYCLE}, check-in=${GATE_TYPE}, direction=${DIRECTION}, velocity=${VELOCITY}. Tell the postdoc this is AUTONOMOUS MODE — they are the final authority. There is no PI escalation. After approval, set mode to 'working', advance step to ${NEXT_STEP}, and continue. Drive the conversation faithfully. You must NEVER read .postdoc/ files."
    fi
}

# ================================================================
# GATE CHECKS
# ================================================================

# --- Gate 1: Monday slides ready (step 0) ---
if [ "$STEP" -eq 0 ] && [ "$HAS_MONDAY" = true ]; then
    case "$REVIEW_MODE" in
        pi_direct)     handle_gate_pi_direct "monday" 1 ;;
        self_review)   handle_gate_self_review "monday" 1 ;;
        postdoc)       handle_gate_postdoc "monday" 1 ;;
        autonomous)    handle_gate_autonomous "monday" 1 ;;
        *)             handle_gate_postdoc "monday" 1 ;;  # default
    esac
fi

# --- Gate 2: Wednesday slides ready (step 2) ---
if [ "$STEP" -eq 2 ] && [ "$HAS_WEDNESDAY" = true ]; then
    case "$REVIEW_MODE" in
        pi_direct)     handle_gate_pi_direct "wednesday" 3 ;;
        self_review)   handle_gate_self_review "wednesday" 3 ;;
        postdoc)       handle_gate_postdoc "wednesday" 3 ;;
        autonomous)    handle_gate_autonomous "wednesday" 3 ;;
        *)             handle_gate_postdoc "wednesday" 3 ;;  # default
    esac
fi

# --- Not at a gate: should block. Check safety valve first. ---
COUNTER_FILE="/tmp/clauto_stop_count_${SESSION_ID}"

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    if [ -f "$COUNTER_FILE" ]; then
        STORED=$(cat "$COUNTER_FILE")
        STORED_STEP=$(echo "$STORED" | cut -d: -f1)
        STORED_COUNT=$(echo "$STORED" | cut -d: -f2)

        if [ "$STORED_STEP" != "$STEP" ]; then
            echo "${STEP}:1" > "$COUNTER_FILE"
        else
            COUNT=$((STORED_COUNT + 1))
            if [ "$COUNT" -ge 3 ]; then
                rm -f "$COUNTER_FILE"
                exit 0
            fi
            echo "${STEP}:${COUNT}" > "$COUNTER_FILE"
        fi
    else
        echo "${STEP}:1" > "$COUNTER_FILE"
    fi
else
    echo "${STEP}:0" > "$COUNTER_FILE"
fi

# --- Build reason message based on current state ---
NEXT_CYCLE=$((CYCLE + 1))
NEXT_CYCLE_FMT=$(printf '%02d' "$NEXT_CYCLE")

if [ "$STEP" -eq 0 ]; then
    if [ "$CYCLE" -eq 1 ]; then
        REASON="Cycle 1, step 0: Deep literature review (Phase 2 of onboarding). Work AUTONOMOUSLY on a thorough literature review: search broadly (Semantic Scholar, arXiv, Google Scholar via web search), identify state of the art, key methods, gaps, and opportunities relative to plan.md. This is THINKING, not building — no code, no experiments. Save findings to cycles/cycle_${CYCLE_FMT}/notes.md and literature/. When done, produce Monday check-in slides (cycle 1 format: literature landscape, gaps & opportunities, possible directions, questions for supervisor). Do NOT stop until Monday slides PDF exists."
    else
        REASON="Cycle $CYCLE started but Monday check-in slides are missing. Produce them NOW: copy templates/checkin_template.tex to cycles/cycle_${CYCLE_FMT}/slides/cycle_${CYCLE_FMT}_monday.tex, fill with last cycle's results and proposed direction/velocity, compile with pdflatex (run twice), update state.yaml last_checkin. Do NOT stop until the Monday PDF exists."
    fi
elif [ "$STEP" -eq 1 ]; then
    REASON="You are exploring (step 1, cycle $CYCLE). Continue: finish literature review, then design the minimal PoC study (step 2), then produce Wednesday check-in slides. Update state.yaml step to 2 when you begin designing. Do NOT stop until Wednesday slides are ready for review."
elif [ "$STEP" -eq 2 ]; then
    REASON="Design is complete (step 2, cycle $CYCLE) but Wednesday slides are missing. Produce them NOW: copy templates/checkin_template.tex to cycles/cycle_${CYCLE_FMT}/slides/cycle_${CYCLE_FMT}_wednesday.tex, fill with literature findings, research question, proposed minimal study, and scoped next steps (ONE deliverable for Wed-Sun). Compile with pdflatex, update state.yaml. Do NOT stop until the Wednesday PDF exists."
elif [ "$STEP" -eq 3 ]; then
    REASON="You are in setup (step 3, cycle $CYCLE). Continue building: finish environment setup and code scaffolding, then get something working end-to-end (step 4), then run the PoC study (step 5). Update state.yaml step as you go. Do NOT stop until execution is complete and Monday slides for cycle $NEXT_CYCLE are ready."
elif [ "$STEP" -eq 4 ]; then
    REASON="You are in GSW phase (step 4, cycle $CYCLE). Continue: get the pipeline running end-to-end, then proceed to step 5 (run the actual PoC study). Update state.yaml step to 5 when the pipeline runs. Do NOT stop until execution is complete and Monday slides for cycle $NEXT_CYCLE are ready."
elif [ "$STEP" -eq 5 ]; then
    REASON="PoC study complete (step 5, cycle $CYCLE). Now transition: increment cycle to $NEXT_CYCLE in state.yaml, reset step to 0, create cycles/cycle_${NEXT_CYCLE_FMT}/ with slides/, code/, results/ subdirs, copy templates/cycle_notes.md to the new cycle, then produce Monday check-in slides for cycle $NEXT_CYCLE. Do NOT stop until Monday slides are ready for review."
else
    REASON="Continue working on cycle $CYCLE step $STEP. Check cycles/cycle_${CYCLE_FMT}/notes.md and state.yaml for what to do next. Do NOT stop until you reach a gate point (slides ready for review)."
fi

cat <<EOF
{
  "decision": "block",
  "reason": "$REASON"
}
EOF
