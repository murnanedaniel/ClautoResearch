---
name: new-project
description: Scaffold a new research project instance under projects/
allowed-tools: Bash, Write, Read, Glob, Edit
---

# New Project

The user wants to create a new research project. Do the following:

1. **Get the project topic** from the user's message (the argument after `/new-project`). If none provided, ask.

2. **Create a short kebab-case name** from the topic (e.g., "graph neural network pruning" → `graph-pruning`).

3. **Scaffold the project directory** under `projects/<name>/`:
   ```
   projects/<name>/
   ├── CLAUDE.md
   ├── state.yaml
   ├── plan.md
   ├── requirements.txt   ← pinned Python dependencies
   ├── src/               ← persistent reusable code
   │   ├── data/          ← data loading, preprocessing
   │   ├── models/        ← model definitions
   │   └── utils/         ← shared utilities
   ├── literature/
   ├── cycles/
   │   └── cycle_01/
   │       ├── slides/
   │       ├── code/      ← this cycle's experiments (notebooks, scripts)
   │       └── results/   ← outputs, plots, metrics
   └── paper/
   ```

4. **Create the project `CLAUDE.md`** with:
   ```markdown
   # <Project Name>

   ## Research Topic
   <topic description from user>

   ## Key Decisions
   (none yet)

   ## Domain Notes
   (to be filled during exploration)
   ```

5. **Create `state.yaml`** with:
   ```yaml
   phase: rd
   cycle: 1
   step: 0
   direction: 0
   velocity: 0
   last_checkin: null
   notes: "Project created. Awaiting first cycle."
   ```

6. **Copy `templates/cycle_notes.md`** to `cycles/cycle_01/notes.md`.

6b. **Create `requirements.txt`** with common scientific Python packages as a starting point:
   ```
   numpy
   pandas
   matplotlib
   scikit-learn
   jupyter
   ```
   Ask the supervisor if there are additional dependencies to add (e.g. `torch`, `jax`, domain-specific packages). Pin versions after installing.

6c. **Create the virtual environment**: `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`. Then update `requirements.txt` with pinned versions: `pip freeze > requirements.txt`.

7. **Start a conversation about the project plan.** Ask the supervisor to describe their vision: the problem space, initial directions, possible outcomes, and any constraints. Distill this into `plan.md` together. This is the north star document — it should capture the research vision at a high level, not a task list.

8. **Confirm** to the user: show the created structure and explain that the project is ready to begin cycle 1 (start exploring and working through the cycle naturally).
