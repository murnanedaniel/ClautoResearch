---
name: write
description: Enter the writing phase for a research project
allowed-tools: Bash, Write, Read, Edit, Glob, Grep, WebSearch, WebFetch, Agent
---

# Writing Phase

The supervisor has decided it's time to write a paper. Switch from R&D to writing mode.

## Procedure

1. **Read `state.yaml`** and update `phase` to `"writing"`.

2. **Create the paper directory** if it doesn't exist: `paper/`.

3. **Gather materials**: Read through all accumulated slide decks, results, and notes from all cycles. Build a mental model of the full research story.

4. **Propose an outline** to the supervisor:
   - Title
   - Abstract (draft)
   - Section structure (Introduction, Related Work, Methods, Experiments, Results, Discussion, Conclusion)
   - Which results/figures go where
   - What's missing (gaps that might need R&D mini-cycles)

5. **Generate a check-in slide deck** for the outline proposal (same format, ~4-6 slides).

6. **Wait for approval** before drafting.

## Writing cycle
Once approved, the writing loop is:
1. Draft sections → 2. Check-in slides → 3. Supervisor review → 4. Revise → repeat

If a result is missing or a figure doesn't hold up, tell the supervisor you need to drop back into an R&D mini-cycle. Update `state.yaml` phase back to `"rd"` temporarily, do the work, then return to writing.

## Paper format
- LaTeX, using an appropriate conference template (NeurIPS, ICML, etc. — ask supervisor which one)
- All source in `paper/`
- Figures referenced from `cycles/` results directories
