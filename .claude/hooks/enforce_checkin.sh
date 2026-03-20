#!/bin/bash
# Enforce check-in slide decks at gate points.
# Runs on every UserPromptSubmit. If the student is past a gate
# (step 2 or step 5) without having produced slides, injects a
# reminder into Claude's context.
#
# Rhythm: Mon-Tue explore → Wednesday check-in → Wed-Sun build → Monday check-in

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

# Check gate conditions
if [ "$STEP" -eq 2 ]; then
    # Wednesday gate: steps 1-2 done, need Wednesday slides
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
elif [ "$STEP" -eq 5 ]; then
    # Monday gate: steps 3-5 done, need Monday slides
    if ! ls "$SLIDES_DIR"/cycle_*_monday.pdf >/dev/null 2>&1; then
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "GATE CHECK: You have completed steps 3-5 of cycle $CYCLE but have NOT produced the Monday check-in slide deck yet. You MUST produce the Monday slide deck (including proposed direction/velocity for next cycle) before doing any other work. See CLAUDE.md for the Monday slide content specification."
  }
}
EOF
        exit 0
    fi
fi

# No gate condition — proceed normally
exit 0
