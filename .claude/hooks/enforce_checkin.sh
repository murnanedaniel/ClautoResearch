#!/bin/bash
# Enforce check-in slide decks at gate points.
# Runs on every UserPromptSubmit. If the student is past a gate
# without having produced slides, injects a reminder.
#
# Rhythm:
#   Monday morning: check-in slides (belongs to NEW cycle)
#   Mon-Tue: explore (steps 1-2)
#   Wednesday morning: check-in slides (same cycle)
#   Wed-Sun: build (steps 3-5)
#   → transition to next cycle → Monday slides → ...
#
# Gate 1: step=2, no wednesday slides in current cycle
# Gate 2: step=0, cycle>1, no monday slides in current cycle
#   (step=0 means just transitioned; monday slides start the new cycle)

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

# Only enforce during R&D phase
if [ "$PHASE" != "rd" ]; then
    exit 0
fi

# Determine the project directory
PROJECT_DIR=$(dirname "$STATE_FILE")
CYCLE_DIR="$PROJECT_DIR/cycles/cycle_$(printf '%02d' "$CYCLE")"
SLIDES_DIR="$CYCLE_DIR/slides"

# Gate 1: Wednesday check-in
# Steps 1-2 done, need Wednesday slides before proceeding to steps 3-5
if [ "$STEP" -eq 2 ]; then
    if ! ls "$SLIDES_DIR"/cycle_*_wednesday.pdf >/dev/null 2>&1; then
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "GATE CHECK: You have completed steps 1-2 of cycle $CYCLE but have NOT produced the Wednesday check-in slide deck yet. You MUST produce the Wednesday slide deck before doing any other work. See CLAUDE.md for the Wednesday slide content specification. Remember: scope slides 4 and 6 to THIS Wed-Sun only — one concrete deliverable, not the whole project."
  }
}
EOF
        exit 0
    fi
fi

# Gate 2: Monday check-in (start of new cycle)
# Cycle has been incremented, step reset to 0, but Monday slides not yet produced.
# Skip for cycle 1 (no prior work to present).
if [ "$STEP" -eq 0 ] && [ "$CYCLE" -gt 1 ]; then
    if ! ls "$SLIDES_DIR"/cycle_*_monday.pdf >/dev/null 2>&1; then
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "GATE CHECK: Cycle $CYCLE has started but you have NOT produced the Monday check-in slide deck yet. You MUST produce the Monday slide deck (presenting last cycle's results and proposing direction/velocity for this cycle) before doing any other work. The Monday slides belong to this cycle — save them in cycles/cycle_$(printf '%02d' "$CYCLE")/slides/."
  }
}
EOF
        exit 0
    fi
fi

# No gate condition — proceed normally
exit 0
