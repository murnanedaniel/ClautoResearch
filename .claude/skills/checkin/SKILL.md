---
name: checkin
description: Generate a Wednesday or Friday check-in slide deck
allowed-tools: Bash, Write, Read, Edit, Glob, Grep
---

# Check-in Slide Deck

Generate a LaTeX Beamer slide deck for the current check-in point.

## Procedure

1. **Read `state.yaml`** to determine the current cycle and step.

2. **Determine check-in type:**
   - After steps 1-2 → **Wednesday check-in**
   - After steps 3-5 → **Friday check-in**

3. **Read the cycle's work** from `cycles/cycle_NN/` — notes, code, results, any generated plots.

4. **Copy the template** from `templates/checkin_template.tex` to `cycles/cycle_NN/slides/cycle_NN_<day>.tex`.

5. **Fill in the slide deck:**

   **Wednesday slides:**
   - Slide 1: Status & Context (cycle number, direction/velocity, goal for this half)
   - Slide 2: Literature Findings (key papers, state of the art, gaps identified)
   - Slide 3: Research Question (the question being asked or refined, with rationale)
   - Slide 4: Proposed Minimal Study (what to build, what to measure, what baselines)
   - Slide 5: Questions for Supervisor (things needing expertise or a decision)
   - Slide 6: Next Steps (what will be done in the second half if approved)

   **Friday slides:**
   - Slide 1: Status & Context (cycle number, direction/velocity, goal for this half)
   - Slide 2: What Was Built (code architecture, key implementation details)
   - Slide 3: Results (plots, tables, metrics — include `\includegraphics` for any generated figures)
   - Slide 4: Hypotheses & Interpretation (what the results mean, working hypotheses)
   - Slide 5: Questions for Supervisor
   - Slide 6: Next Steps + Proposed Direction/Velocity for next cycle

6. **Compile** with `pdflatex` (run twice for references). Verify it produces a PDF.

7. **Update `state.yaml`**: set `last_checkin` to the path of the generated PDF.

8. **Present to supervisor**: Tell the user the slide deck is ready at the given path, and that they should review it before approving the next phase.
