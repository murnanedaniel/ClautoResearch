#!/bin/bash
# Enforce check-in slide decks and meeting notes at gate points.
# Runs on every UserPromptSubmit. Injects reminders when the student
# is missing required slides or hasn't synced notes after a meeting.
#
# Rhythm:
#   Monday morning: check-in slides (belongs to NEW cycle)
#   Mon-Tue: explore (steps 1-2)
#   Wednesday morning: check-in slides (same cycle)
#   Wed-Sun: build (steps 3-5)
#   → transition to next cycle → Monday slides → ...
#
# Gate 1 (Monday): cycle>1 and no monday slides → block everything
# Gate 2 (Wednesday): no wednesday slides and step>=1 → block execution work
#   - step>=2: hard gate (exploration done, slides overdue)
#   - step=1: soft gate (still exploring, but no code/training allowed)
# Gate 3 (Notes sync): slides exist but notes.md not updated since slides
#   were produced → remind to sync meeting outcomes before proceeding

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

# Only enforce during R&D phase
if [ "$PHASE" != "rd" ]; then
    exit 0
fi

# In meeting mode: inject meeting behavior, skip normal gates
if [ "$MODE" = "meeting" ]; then
    # Determine which meeting this is
    if [ "$STEP" -eq 0 ] && [ "$CYCLE" -gt 1 ]; then
        MEETING_TYPE="Monday"
    else
        MEETING_TYPE="Wednesday"
    fi
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "MEETING MODE ($MEETING_TYPE check-in, cycle $CYCLE): You are in an interactive meeting with the supervisor. Be conversational and responsive — answer questions, generate ad-hoc plots, explain results, discuss alternatives. You may run quick analysis code and generate visualizations if the supervisor asks.\n\nDo NOT: start autonomous execution work, write production code, begin the next phase, or update state.yaml step.\n\nWRAP-UP PROTOCOL: When you sense the meeting is concluding — the supervisor has reviewed all slides, questions have been discussed, and next steps are clear — use AskUserQuestion to propose wrapping up. But ONLY when ALL of these are true:\n  - The supervisor's questions (slide 5) have been addressed\n  - Next steps / direction have been discussed\n  - The supervisor signals satisfaction ('looks good', 'let's do that', 'go ahead', 'approved', etc.)\n\nDo NOT propose wrapping up if:\n  - The supervisor is actively asking questions or exploring data\n  - You are mid-discussion of a slide or result\n  - The supervisor just asked you to generate a plot or analysis\n  - There are unresolved questions or open threads\n\nWhen proposing wrap-up, use AskUserQuestion with options: 'Approve & proceed' (begin next phase), 'Continue discussion' (stay in meeting), 'Revise plan' (update slides/plan before approving).\n\nIf approved: record meeting outcomes in notes.md, set mode back to 'working' in state.yaml, advance the step, and resume autonomous work."
  }
}
EOF
    exit 0
fi

# Determine the project directory
PROJECT_DIR=$(dirname "$STATE_FILE")
CYCLE_DIR="$PROJECT_DIR/cycles/cycle_$(printf '%02d' "$CYCLE")"
SLIDES_DIR="$CYCLE_DIR/slides"

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
# If Monday slides are missing, nothing else should happen — regardless of step.
# The student may have jumped ahead without producing Monday slides.
if [ "$CYCLE" -gt 1 ] && [ "$HAS_MONDAY" = false ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "HARD GATE — MONDAY SLIDES MISSING: Cycle $CYCLE has started but you have NOT produced the Monday check-in slide deck. You MUST produce the Monday slide deck IMMEDIATELY — do not do ANY other work until it is done. No code, no experiments, no literature search. Monday slides first. Present last cycle's results and propose direction/velocity for this cycle. Save in cycles/cycle_$(printf '%02d' "$CYCLE")/slides/."
  }
}
EOF
    exit 0
fi

# Gate 2: Wednesday check-in
# Fires on EVERY prompt when Wednesday slides are missing and step >= 1.
# This prevents the student from doing execution work during exploration.
if [ "$HAS_WEDNESDAY" = false ] && [ "$STEP" -ge 1 ]; then
    if [ "$STEP" -ge 2 ]; then
        # Hard gate: exploration is done, slides are overdue
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "HARD GATE — WEDNESDAY SLIDES OVERDUE: You are on step $STEP of cycle $CYCLE but have NOT produced the Wednesday check-in slide deck. You MUST produce the Wednesday slide deck NOW. Do NOT write code, train models, download data, set up environments, or do any execution work. Produce the slides FIRST, then STOP and wait for supervisor approval. See CLAUDE.md for the Wednesday slide content specification. Scope slides 4 and 6 to THIS Wed-Sun only."
  }
}
EOF
    else
        # Soft gate: still in exploration, remind about boundaries
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "EXPLORATION PHASE — NO EXECUTION WORK: You are on step $STEP of cycle $CYCLE. Wednesday slides have not been produced yet. During steps 1-2 you may ONLY: search literature, read papers, take notes, analyze existing data/results, and design a study. You must NOT: write code, train models, download datasets, clone repos, set up environments, create scripts, or run experiments. Those are steps 3-5 and require Wednesday slide approval first. When steps 1-2 are complete, produce Wednesday slides and STOP."
  }
}
EOF
    fi
    exit 0
fi

# Gate 3: Post-meeting notes sync
# After a check-in meeting, the student must update cycle notes with
# meeting outcomes before starting new work. Check: if slides exist
# and the student is past the meeting point, notes.md must have been
# modified MORE RECENTLY than the slides PDF.
NOTES_FILE="$CYCLE_DIR/notes.md"
if [ -f "$NOTES_FILE" ]; then
    NOTES_MTIME=$(stat -c %Y "$NOTES_FILE" 2>/dev/null || echo 0)

    # After Wednesday meeting: step >= 3, Wednesday slides exist
    if [ "$STEP" -ge 3 ] && [ "$HAS_WEDNESDAY" = true ]; then
        WEDNESDAY_PDF=$(ls -t "$SLIDES_DIR"/cycle_*_wednesday.pdf 2>/dev/null | head -1)
        if [ -n "$WEDNESDAY_PDF" ]; then
            SLIDES_MTIME=$(stat -c %Y "$WEDNESDAY_PDF" 2>/dev/null || echo 0)
            if [ "$NOTES_MTIME" -lt "$SLIDES_MTIME" ]; then
                cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "MEETING NOTES NOT SYNCED: You are starting execution (step $STEP) but have not updated cycle notes since the Wednesday check-in meeting. Before doing any work, you MUST: (1) Read cycles/cycle_$(printf '%02d' "$CYCLE")/notes.md, (2) Update the Wed-Sun execution section with meeting outcomes — what the supervisor approved, any changes to the plan, key decisions made, and any feedback received. This ensures the approved plan is recorded before you act on it."
  }
}
EOF
                exit 0
            fi
        fi
    fi

    # After Monday meeting: step >= 1, Monday slides exist (cycle > 1)
    if [ "$STEP" -ge 1 ] && [ "$CYCLE" -gt 1 ] && [ "$HAS_MONDAY" = true ]; then
        MONDAY_PDF=$(ls -t "$SLIDES_DIR"/cycle_*_monday.pdf 2>/dev/null | head -1)
        if [ -n "$MONDAY_PDF" ]; then
            SLIDES_MTIME=$(stat -c %Y "$MONDAY_PDF" 2>/dev/null || echo 0)
            if [ "$NOTES_MTIME" -lt "$SLIDES_MTIME" ]; then
                cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "MEETING NOTES NOT SYNCED: You are starting exploration (step $STEP) but have not updated cycle notes since the Monday check-in meeting. Before doing any work, you MUST: (1) Read cycles/cycle_$(printf '%02d' "$CYCLE")/notes.md, (2) Update the Mon-Tue exploration section with meeting outcomes — supervisor's direction/velocity decision, approved exploration focus, any constraints or redirections. This ensures you explore what was actually agreed, not what you originally proposed."
  }
}
EOF
                exit 0
            fi
        fi
    fi
fi

# No gate condition — proceed normally
exit 0
