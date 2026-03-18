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
   ├── literature/
   ├── cycles/
   │   └── cycle_01/
   │       ├── slides/
   │       ├── code/
   │       └── results/
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

6. **Confirm** to the user: show the created structure and suggest they start with `/rd-cycle` to begin cycle 1.
