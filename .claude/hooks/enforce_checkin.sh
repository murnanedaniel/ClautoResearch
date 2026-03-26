#!/bin/bash
# Enforce check-in slide decks and meeting notes at gate points.
# Runs on every UserPromptSubmit. Injects reminders when the student
# is missing required slides or hasn't synced notes after a meeting.
#
# Review modes (review_mode in state.yaml):
#   pi_direct    — PI reviews every gate directly
#   self_review  — Student self-reviews, PI at cadence
#   postdoc      — Postdoc subagent reviews, PI at cadence
#   autonomous   — Postdoc reviews, no PI stops
#
# Mode states:
#   working        — autonomous work in progress
#   self_review    — self-review checklist in progress
#   postdoc_review — postdoc subagent review in progress
#   meeting        — PI meeting in progress
#
# Gates:
#   Gate 1 (Monday): cycle>1 and no monday slides → block everything
#   Gate 2 (Wednesday): no wednesday slides and step>=1 → block execution work
#   Gate 3 (Notes sync): slides exist but notes.md not updated → remind

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Find the most recently modified state.yaml under projects/
PROJECTS_DIR="$CLAUDE_PROJECT_DIR/projects"
if [ ! -d "$PROJECTS_DIR" ]; then
    exit 0
fi

STATE_FILE=$(find "$PROJECTS_DIR" -name "state.yaml" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -z "$STATE_FILE" ]; then
    exit 0
fi

# Parse state.yaml (simple grep — no yq dependency)
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

# Determine project directory
PROJECT_DIR=$(dirname "$STATE_FILE")
CYCLE_DIR="$PROJECT_DIR/cycles/cycle_$(printf '%02d' "$CYCLE")"
SLIDES_DIR="$CYCLE_DIR/slides"
CYCLE_FMT=$(printf '%02d' "$CYCLE")

# Determine if this is a PI meeting cycle
IS_PI_MEETING=false
if [ "$REVIEW_MODE" = "pi_direct" ]; then
    IS_PI_MEETING=true
elif [ "$REVIEW_MODE" = "autonomous" ]; then
    IS_PI_MEETING=false
else
    if [ "$CYCLE" -eq 1 ]; then
        IS_PI_MEETING=true
    elif [ "$ESCALATION" != "null" ] && [ "$ESCALATION" != "" ]; then
        IS_PI_MEETING=true
    elif [ "$SUPERVISOR_CADENCE" -gt 0 ] && [ $((CYCLE % SUPERVISOR_CADENCE)) -eq 0 ]; then
        IS_PI_MEETING=true
    fi
fi

# --- Helper: emit context injection ---
inject_context() {
    local CONTEXT="$1"
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "$CONTEXT"
  }
}
EOF
    exit 0
}

# ================================================================
# MODE-SPECIFIC CONTEXT INJECTION
# ================================================================

# --- Self-review mode ---
if [ "$MODE" = "self_review" ]; then
    DIRECTION=$(grep '^direction:' "$STATE_FILE" | awk '{print $2}')
    VELOCITY=$(grep '^velocity:' "$STATE_FILE" | awk '{print $2}')

    if [ "$STEP" -eq 0 ]; then
        CHECKIN_TYPE="monday"
    else
        CHECKIN_TYPE="wednesday"
    fi

    if [ "$IS_PI_MEETING" = true ]; then
        AFTER_MSG="After completing self-review: record your assessment in cycle notes under '## Gate Review', set mode to 'meeting' in state.yaml, then stop for PI meeting."
    else
        if [ "$STEP" -eq 0 ]; then NEXT_STEP=1; else NEXT_STEP=3; fi
        AFTER_MSG="After completing self-review: record your assessment in cycle notes under '## Gate Review', set mode to 'working' in state.yaml, advance step to ${NEXT_STEP}, and CONTINUE working autonomously (do NOT stop)."
    fi

    inject_context "SELF-REVIEW MODE (cycle $CYCLE, ${CHECKIN_TYPE} check-in, direction=${DIRECTION}, velocity=${VELOCITY}): Read templates/self_review_prompt.md and review your slides against ALL criteria (methodology, scope, literature, results, alignment, presentation). Be honest and thorough — you are your own quality gate. If you find issues, fix them and recompile slides before proceeding. ${AFTER_MSG}"
fi

# --- Postdoc review mode ---
if [ "$MODE" = "postdoc_review" ]; then
    DIRECTION=$(grep '^direction:' "$STATE_FILE" | awk '{print $2}')
    VELOCITY=$(grep '^velocity:' "$STATE_FILE" | awk '{print $2}')

    if [ "$STEP" -eq 0 ]; then
        CHECKIN_TYPE="monday"
        SLIDE_PATH="${SLIDES_DIR}/cycle_${CYCLE_FMT}_monday.pdf"
    else
        CHECKIN_TYPE="wednesday"
        SLIDE_PATH="${SLIDES_DIR}/cycle_${CYCLE_FMT}_wednesday.pdf"
    fi

    if [ "$REVIEW_MODE" = "autonomous" ]; then
        PI_INFO="This is AUTONOMOUS MODE. After postdoc APPROVED: record feedback, update direction/velocity per postdoc adjustments, set mode to 'working', advance step, and CONTINUE working. There are no PI meetings in autonomous mode. The postdoc is the final authority."
    elif [ "$IS_PI_MEETING" = true ] && [ "$STEP" -eq 0 ]; then
        PI_INFO="This is a PI MEETING CYCLE (cycle $CYCLE). Tell the postdoc this is a PI meeting cycle so they prepare a PI brief in .postdoc/pi_brief.md. After postdoc APPROVED: set mode to 'meeting' and stop for PI review. After ESCALATE: same — set mode to 'meeting' and stop."
    else
        if [ "$STEP" -eq 0 ]; then NEXT_STEP=1; else NEXT_STEP=3; fi
        PI_INFO="This is a NORMAL CYCLE (postdoc-only). After postdoc APPROVED: record feedback, update direction/velocity per postdoc adjustments, set mode to 'working', advance step to ${NEXT_STEP}, and CONTINUE working. After ESCALATE: set mode to 'meeting' and stop for immediate PI meeting."
    fi

    inject_context "POSTDOC REVIEW MODE (cycle $CYCLE, ${CHECKIN_TYPE} check-in): If you haven't spawned the postdoc subagent yet, do so NOW using the Agent tool. Read templates/postdoc_prompt.md for the system prompt. Provide these artifacts: slide=${SLIDE_PATH}, notes=${CYCLE_DIR}/notes.md, results=${CYCLE_DIR}/results/, code=${CYCLE_DIR}/code/, plan=${PROJECT_DIR}/plan.md, project=${PROJECT_DIR}, cycle=${CYCLE}, check-in=${CHECKIN_TYPE}, direction=${DIRECTION}, velocity=${VELOCITY}. ${PI_INFO} Drive the conversation faithfully — relay ALL postdoc requests, provide raw data not summaries. You must NEVER read .postdoc/ files."
fi

# --- Meeting mode (PI meeting) ---
if [ "$MODE" = "meeting" ]; then
    # Determine which meeting this is
    if [ "$STEP" -eq 0 ] && [ "$CYCLE" -eq 1 ]; then
        MEETING_TYPE="Planning"
    elif [ "$STEP" -eq 0 ] && [ "$CYCLE" -gt 1 ]; then
        MEETING_TYPE="Monday"
    else
        MEETING_TYPE="Wednesday"
    fi

    # Check for PI brief to inject
    PI_BRIEF_SECTION=""
    PI_BRIEF_FILE="$PROJECT_DIR/.postdoc/pi_brief.md"
    if [ -f "$PI_BRIEF_FILE" ] && [ "$MEETING_TYPE" != "Planning" ]; then
        PI_BRIEF_CONTENT=$(cat "$PI_BRIEF_FILE" 2>/dev/null || echo "")
        if [ -n "$PI_BRIEF_CONTENT" ]; then
            PI_BRIEF_ESCAPED=$(echo "$PI_BRIEF_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
            PI_BRIEF_SECTION="\\n\\nPOSTDOC BRIEF (private assessment from the postdoc — the student has not seen this):\\n${PI_BRIEF_ESCAPED}"
        fi
    fi

    # Planning meetings have different context than check-in meetings
    if [ "$MEETING_TYPE" = "Planning" ]; then
        MEETING_CONTEXT="MEETING MODE (Pre-project planning): You are in an interactive planning meeting with the supervisor. This is the initial scoping conversation for the project. Be conversational and collaborative — discuss the research vision, ask clarifying questions, help refine scope.\n\nFocus on:\n  - Understanding the problem space and research question\n  - Discussing what success looks like and what's in/out of scope\n  - Agreeing on initial direction/velocity\n  - Iterating on plan.md together\n  - Identifying initial literature directions for cycle 1 exploration\n\nDo NOT: start exploration, write code, search literature, or do any autonomous work. This is a conversation, not a work session.\n\nWRAP-UP PROTOCOL: When you sense the meeting is concluding — the project scope is clear, plan.md captures the vision, and the supervisor is satisfied with the starting direction — use AskUserQuestion to propose wrapping up. But ONLY when ALL of these are true:\n  - The research question or problem space is reasonably defined\n  - plan.md has been drafted or updated with mutual agreement\n  - Initial direction for cycle 1 exploration has been discussed\n  - The supervisor signals satisfaction ('looks good', 'let's get started', 'that's a good plan', etc.)\n\nDo NOT propose wrapping up if:\n  - The supervisor is still describing the problem or refining scope\n  - There are open questions about what the project should focus on\n  - plan.md hasn't been discussed or is clearly incomplete\n\nWhen proposing wrap-up, use AskUserQuestion with options: 'Approve & proceed' (finalize plan.md, begin cycle 1 exploration), 'Continue discussion' (stay in meeting), 'Revise plan' (update plan.md before approving).\n\nIf approved: finalize plan.md, record any decisions in cycle_01/notes.md, set mode to 'working' in state.yaml, advance step to 1, and begin autonomous exploration (literature review, research question refinement, toward producing Wednesday slides)."
    else
        MEETING_CONTEXT="MEETING MODE (PI ${MEETING_TYPE} check-in, cycle $CYCLE): You are in an interactive meeting with the PI (supervisor). The postdoc has already reviewed your work and approved it (or escalated). Be conversational and responsive — answer questions, generate ad-hoc plots, explain results, discuss alternatives. You may run quick analysis code and generate visualizations if the supervisor asks.${PI_BRIEF_SECTION}\n\nDo NOT: start autonomous execution work, write production code, begin the next phase, or update state.yaml step.\n\nIf this meeting was triggered by ESCALATION: the escalation reason is recorded in state.yaml. Address the escalation issue directly with the PI. After the meeting, reset escalation to null in state.yaml.\n\nWRAP-UP PROTOCOL: When you sense the meeting is concluding — the supervisor has reviewed all slides, questions have been discussed, and next steps are clear — use AskUserQuestion to propose wrapping up. But ONLY when ALL of these are true:\n  - The supervisor's questions (slide 5) have been addressed\n  - Next steps / direction have been discussed\n  - The supervisor signals satisfaction ('looks good', 'let's do that', 'go ahead', 'approved', etc.)\n\nDo NOT propose wrapping up if:\n  - The supervisor is actively asking questions or exploring data\n  - You are mid-discussion of a slide or result\n  - The supervisor just asked you to generate a plot or analysis\n  - There are unresolved questions or open threads\n\nWhen proposing wrap-up, use AskUserQuestion with options: 'Approve & proceed' (begin next phase), 'Continue discussion' (stay in meeting), 'Revise plan' (update slides/plan before approving).\n\nIf approved: record meeting outcomes in notes.md (including any PI overrides to direction/velocity), reset escalation to null if set, set mode back to 'working' in state.yaml, advance the step, and resume autonomous work."
    fi

    inject_context "$MEETING_CONTEXT"
fi

# ================================================================
# WORKING MODE: enforce gates
# ================================================================

# Check for existing slides
HAS_MONDAY=false
HAS_WEDNESDAY=false
if ls "$SLIDES_DIR"/cycle_*_monday.pdf >/dev/null 2>&1; then
    HAS_MONDAY=true
fi
if ls "$SLIDES_DIR"/cycle_*_wednesday.pdf >/dev/null 2>&1; then
    HAS_WEDNESDAY=true
fi

# Gate 1: Monday check-in (cycle > 1)
if [ "$CYCLE" -gt 1 ] && [ "$HAS_MONDAY" = false ]; then
    inject_context "HARD GATE — MONDAY SLIDES MISSING: Cycle $CYCLE has started but you have NOT produced the Monday check-in slide deck. You MUST produce the Monday slide deck IMMEDIATELY — do not do ANY other work until it is done. No code, no experiments, no literature search. Monday slides first. Present last cycle's results and propose direction/velocity for this cycle. Save in cycles/cycle_${CYCLE_FMT}/slides/."
fi

# Gate 2: Wednesday check-in
if [ "$HAS_WEDNESDAY" = false ] && [ "$STEP" -ge 1 ]; then
    if [ "$STEP" -ge 2 ]; then
        inject_context "HARD GATE — WEDNESDAY SLIDES OVERDUE: You are on step $STEP of cycle $CYCLE but have NOT produced the Wednesday check-in slide deck. You MUST produce the Wednesday slide deck NOW. Do NOT write code, train models, download data, set up environments, or do any execution work. Produce the slides FIRST, then STOP and wait for supervisor approval. See CLAUDE.md for the Wednesday slide content specification. Scope slides 4 and 6 to THIS Wed-Sun only."
    else
        inject_context "EXPLORATION PHASE — NO EXECUTION WORK: You are on step $STEP of cycle $CYCLE. Wednesday slides have not been produced yet. During steps 1-2 you may ONLY: search literature, read papers, take notes, analyze existing data/results, and design a study. You must NOT: write code, train models, download datasets, clone repos, set up environments, create scripts, or run experiments. Those are steps 3-5 and require Wednesday slide approval first. When steps 1-2 are complete, produce Wednesday slides and STOP."
    fi
fi

# Gate 3: Post-meeting notes sync
NOTES_FILE="$CYCLE_DIR/notes.md"
if [ -f "$NOTES_FILE" ]; then
    NOTES_MTIME=$(stat -c %Y "$NOTES_FILE" 2>/dev/null || echo 0)

    if [ "$STEP" -ge 3 ] && [ "$HAS_WEDNESDAY" = true ]; then
        WEDNESDAY_PDF=$(ls -t "$SLIDES_DIR"/cycle_*_wednesday.pdf 2>/dev/null | head -1)
        if [ -n "$WEDNESDAY_PDF" ]; then
            SLIDES_MTIME=$(stat -c %Y "$WEDNESDAY_PDF" 2>/dev/null || echo 0)
            if [ "$NOTES_MTIME" -lt "$SLIDES_MTIME" ]; then
                inject_context "MEETING NOTES NOT SYNCED: You are starting execution (step $STEP) but have not updated cycle notes since the Wednesday check-in. Before doing any work, you MUST: (1) Read cycles/cycle_${CYCLE_FMT}/notes.md, (2) Update the Wed-Sun execution section with review outcomes — what was approved, any changes to the plan, key decisions made, and any feedback received. This ensures the approved plan is recorded before you act on it."
            fi
        fi
    fi

    if [ "$STEP" -ge 1 ] && [ "$CYCLE" -gt 1 ] && [ "$HAS_MONDAY" = true ]; then
        MONDAY_PDF=$(ls -t "$SLIDES_DIR"/cycle_*_monday.pdf 2>/dev/null | head -1)
        if [ -n "$MONDAY_PDF" ]; then
            SLIDES_MTIME=$(stat -c %Y "$MONDAY_PDF" 2>/dev/null || echo 0)
            if [ "$NOTES_MTIME" -lt "$SLIDES_MTIME" ]; then
                inject_context "MEETING NOTES NOT SYNCED: You are starting exploration (step $STEP) but have not updated cycle notes since the Monday check-in. Before doing any work, you MUST: (1) Read cycles/cycle_${CYCLE_FMT}/notes.md, (2) Update the Mon-Tue exploration section with review outcomes — direction/velocity decision, approved exploration focus, any constraints or redirections. This ensures you explore what was actually agreed, not what you originally proposed."
            fi
        fi
    fi
fi

# No gate condition — proceed normally
exit 0
