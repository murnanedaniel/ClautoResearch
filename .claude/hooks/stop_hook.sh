#!/bin/bash
# Stop hook: prevent Claude from stopping when autonomous work remains.
# Fires when Claude tries to end its turn. Blocks unless at a gate point
# (slides ready for supervisor review).
#
# Gate points (stopping IS correct):
#   1. step=0, Monday slides exist → supervisor reviews Monday deck (all cycles)
#   2. any cycle, step=2, Wednesday slides exist → supervisor reviews Wednesday deck
#
# Everything else in phase=rd → block with specific instructions.
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

# Only enforce during R&D phase
if [ "$PHASE" != "rd" ]; then
    exit 0
fi

# In meeting mode, always allow stop (student should be conversational)
if [ "$MODE" = "meeting" ]; then
    rm -f "/tmp/clauto_stop_count_${SESSION_ID}"
    exit 0
fi

# --- Check slides ---
PROJECT_DIR=$(dirname "$STATE_FILE")
CYCLE_DIR="$PROJECT_DIR/cycles/cycle_$(printf '%02d' "$CYCLE")"
SLIDES_DIR="$CYCLE_DIR/slides"

HAS_MONDAY=false
HAS_WEDNESDAY=false
if ls "$SLIDES_DIR"/cycle_*_monday.pdf >/dev/null 2>&1; then
    HAS_MONDAY=true
fi
if ls "$SLIDES_DIR"/cycle_*_wednesday.pdf >/dev/null 2>&1; then
    HAS_WEDNESDAY=true
fi

# --- Gate check: is this a valid stopping point? ---
# Gate 1: Monday slides ready for review (step 0, any cycle including cycle 1)
if [ "$STEP" -eq 0 ] && [ "$HAS_MONDAY" = true ]; then
    # Enter meeting mode so supervisor can review slides interactively
    sed -i 's/^mode:.*/mode: meeting/' "$STATE_FILE"
    if ! grep -q '^mode:' "$STATE_FILE"; then
        echo "mode: meeting" >> "$STATE_FILE"
    fi
    rm -f "/tmp/clauto_stop_count_${SESSION_ID}"
    exit 0
fi

# Gate 2: Wednesday slides ready for review (step 2, slides exist)
if [ "$STEP" -eq 2 ] && [ "$HAS_WEDNESDAY" = true ]; then
    # Enter meeting mode so supervisor can review slides interactively
    sed -i 's/^mode:.*/mode: meeting/' "$STATE_FILE"
    if ! grep -q '^mode:' "$STATE_FILE"; then
        echo "mode: meeting" >> "$STATE_FILE"
    fi
    rm -f "/tmp/clauto_stop_count_${SESSION_ID}"
    exit 0
fi

# --- Not at a gate: should block. Check safety valve first. ---
COUNTER_FILE="/tmp/clauto_stop_count_${SESSION_ID}"

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    if [ -f "$COUNTER_FILE" ]; then
        STORED=$(cat "$COUNTER_FILE")
        STORED_STEP=$(echo "$STORED" | cut -d: -f1)
        STORED_COUNT=$(echo "$STORED" | cut -d: -f2)

        if [ "$STORED_STEP" != "$STEP" ]; then
            # Step changed — progress was made, reset counter
            echo "${STEP}:1" > "$COUNTER_FILE"
        else
            COUNT=$((STORED_COUNT + 1))
            if [ "$COUNT" -ge 3 ]; then
                # Safety valve: stuck at same step 3 times, let it stop
                rm -f "$COUNTER_FILE"
                exit 0
            fi
            echo "${STEP}:${COUNT}" > "$COUNTER_FILE"
        fi
    else
        echo "${STEP}:1" > "$COUNTER_FILE"
    fi
else
    # First block — initialize counter
    echo "${STEP}:0" > "$COUNTER_FILE"
fi

# --- Build reason message based on current state ---
CYCLE_FMT=$(printf '%02d' "$CYCLE")
NEXT_CYCLE=$((CYCLE + 1))
NEXT_CYCLE_FMT=$(printf '%02d' "$NEXT_CYCLE")

if [ "$STEP" -eq 0 ]; then
    if [ "$CYCLE" -eq 1 ]; then
        REASON="Cycle 1, step 0: Deep literature review (Phase 2 of onboarding). Work AUTONOMOUSLY on a thorough literature review: search broadly (Semantic Scholar, arXiv, Google Scholar via web search), identify state of the art, key methods, gaps, and opportunities relative to plan.md. This is THINKING, not building — no code, no experiments. Save findings to cycles/cycle_${CYCLE_FMT}/notes.md and literature/. When done, produce Monday check-in slides (cycle 1 format: literature landscape, gaps & opportunities, possible directions, questions for supervisor). Do NOT stop until Monday slides PDF exists."
    else
        REASON="Cycle $CYCLE started but Monday check-in slides are missing. Produce them NOW: copy templates/checkin_template.tex to cycles/cycle_${CYCLE_FMT}/slides/cycle_${CYCLE_FMT}_monday.tex, fill with last cycle's results and proposed direction/velocity, compile with pdflatex (run twice), update state.yaml last_checkin. Do NOT stop until the Monday PDF exists."
    fi
elif [ "$STEP" -eq 1 ]; then
    REASON="You are exploring (step 1, cycle $CYCLE). Continue: finish literature review, then design the minimal PoC study (step 2), then produce Wednesday check-in slides. Update state.yaml step to 2 when you begin designing. Do NOT stop until Wednesday slides are ready for supervisor review."
elif [ "$STEP" -eq 2 ]; then
    REASON="Design is complete (step 2, cycle $CYCLE) but Wednesday slides are missing. Produce them NOW: copy templates/checkin_template.tex to cycles/cycle_${CYCLE_FMT}/slides/cycle_${CYCLE_FMT}_wednesday.tex, fill with literature findings, research question, proposed minimal study, and scoped next steps (ONE deliverable for Wed-Sun). Compile with pdflatex, update state.yaml. Do NOT stop until the Wednesday PDF exists."
elif [ "$STEP" -eq 3 ]; then
    REASON="You are in setup (step 3, cycle $CYCLE). Continue building: finish environment setup and code scaffolding, then get something working end-to-end (step 4), then run the PoC study (step 5). Update state.yaml step as you go. Do NOT stop until execution is complete and Monday slides for cycle $NEXT_CYCLE are ready."
elif [ "$STEP" -eq 4 ]; then
    REASON="You are in GSW phase (step 4, cycle $CYCLE). Continue: get the pipeline running end-to-end, then proceed to step 5 (run the actual PoC study). Update state.yaml step to 5 when the pipeline runs. Do NOT stop until execution is complete and Monday slides for cycle $NEXT_CYCLE are ready."
elif [ "$STEP" -eq 5 ]; then
    REASON="PoC study complete (step 5, cycle $CYCLE). Now transition: increment cycle to $NEXT_CYCLE in state.yaml, reset step to 0, create cycles/cycle_${NEXT_CYCLE_FMT}/ with slides/, code/, results/ subdirs, copy templates/cycle_notes.md to the new cycle, then produce Monday check-in slides for cycle $NEXT_CYCLE. Do NOT stop until Monday slides are ready for supervisor review."
else
    REASON="Continue working on cycle $CYCLE step $STEP. Check cycles/cycle_${CYCLE_FMT}/notes.md and state.yaml for what to do next. Do NOT stop until you reach a gate point (slides ready for supervisor review)."
fi

cat <<EOF
{
  "decision": "block",
  "reason": "$REASON"
}
EOF
