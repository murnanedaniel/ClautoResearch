#!/bin/bash
# PostToolUse hook for Bash: detect SLURM job submissions and
# inject a reminder to actively monitor the job.
# Fires after every Bash tool call that matches.

set -euo pipefail

INPUT=$(cat)

# Check for SLURM job submission in the tool output
if echo "$INPUT" | grep -q "Submitted batch job"; then
    JOB_ID=$(echo "$INPUT" | grep -oP 'Submitted batch job \K[0-9]+' | head -1)
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "SLURM JOB SUBMITTED (job ${JOB_ID:-unknown}): You MUST actively monitor this job — do NOT fire-and-forget. Immediately: (1) Run squeue in the background to watch for state changes, (2) Once RUNNING, tail the output log to catch early failures (import errors, OOM, data not found), (3) Check back every few minutes for progress (loss, metrics). Do useful work while waiting, but you own this job until it completes or you hand off to the supervisor."
  }
}
EOF
    exit 0
fi

exit 0
