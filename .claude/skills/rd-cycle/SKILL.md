---
name: rd-cycle
description: Run the next step in the current R&D cycle
allowed-tools: Bash, Write, Read, Edit, Glob, Grep, WebSearch, WebFetch, Agent
---

# R&D Cycle Step

Run the next step in the current R&D cycle for the active project.

## Procedure

1. **Find the active project.** Look for a `state.yaml` in the most recently modified project under `projects/`. If ambiguous, ask the user which project.

2. **Read `state.yaml`** to determine current cycle, step, direction, and velocity.

3. **Execute the current step** based on `state.yaml`:

   - **Step 1: Explore & Define** — Search literature (Semantic Scholar, arXiv, Google Scholar via web search). Identify state of the art. Simultaneously refine the research question. Save findings to `cycles/cycle_NN/notes.md` and `literature/`.

   - **Step 2: Design Minimal PoC** — Based on literature and the research question, define the novel contribution. Design the most-minimal study to test it. Document the study design in `cycles/cycle_NN/notes.md`.

   After steps 1-2: **stop and tell the user to run `/checkin` for the Wednesday check-in.** Do not proceed without approval.

   - **Step 3: Set Up** — Explore data sources, required tools, set up environment. Create code scaffolding in `cycles/cycle_NN/code/`. Document setup in notes.

   - **Step 4: Get Something Working (GSW)** — Write and run code to get an end-to-end pipeline working. Results can be garbage — the goal is proving the machinery runs. Save outputs to `cycles/cycle_NN/results/`.

   - **Step 5: Run PoC Study** — Run the actual minimal study designed in step 2. Collect real results. Generate plots. Save to `cycles/cycle_NN/results/`.

   After steps 3-5: **stop and tell the user to run `/checkin` for the Friday check-in.** Do not proceed without approval.

4. **Update `state.yaml`** after completing the step: increment the step number.

5. **Respect direction and velocity.** Low direction = explore broadly, consider alternatives. High direction = stay focused on the defined question. Low velocity = be thorough, read more, think more. High velocity = move fast, minimal deliberation.

## After Friday approval
If the supervisor approves and the cycle is complete (step 5 done), reset to step 1 and increment the cycle number. Apply any direction/velocity adjustments the supervisor specified.
