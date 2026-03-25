---
name: new-project
description: Scaffold a new research project instance under projects/
allowed-tools: Bash, Write, Read, Glob, Edit
---

# New Project

The user wants to create a new research project. Do the following:

1. **Get the project topic** from the user's message (the argument after `/new-project`). If none provided, ask.

2. **Create a short kebab-case name** from the topic (e.g., "graph neural network pruning" → `graph-pruning`).

3. **Collect supervisor preferences.**

   a. **Check for saved preferences**: Use `Glob` to look for `supervisor_preferences.md` in the memory directory (`/home/murnanedaniel/.claude/projects/-home-murnanedaniel-Research-AIScientists-ClautoResearch/memory/`). If found, `Read` it to get previously saved preferences.

   b. **Generate topic-relevant preference questions.** Based on the project topic, come up with 3-6 multiple-choice preference questions that are relevant to THIS project. Only ask what matters for the topic — don't ask about GNN libraries for a statistics project, don't ask about data serialization formats for a pure theory project.

      Common categories (use as inspiration, not a checklist):
      - DL framework (PyTorch / PyTorch Lightning / JAX / TensorFlow / None)
      - Domain-specific libraries (e.g. PyG, DGL, HuggingFace Transformers, spaCy, ROOT, awkward-array, astropy)
      - Experiment tracking (W&B, MLflow, TensorBoard, None)
      - Visualization (matplotlib, seaborn, plotly, domain-specific like cartopy)
      - Data format (CSV, Parquet, HDF5, ROOT, NetCDF, zarr)
      - Compute environment (Local, SLURM cluster, Cloud GPU)

      Examples of how questions should vary by topic:
      - **"GNN for particle tracking"** → DL framework, GNN library, data format, compute, experiment tracking
      - **"LLM evaluation benchmark"** → inference framework (vLLM / HF transformers / API-only), evaluation harness, compute
      - **"Statistical analysis of climate data"** → stats framework, data format, visualization, compute

   c. **Pre-fill from saved preferences.** If saved preferences exist and any categories match (even approximately), show the saved answer as the default. Present all questions in a single compact numbered list.

      **If saved preferences exist**, format like:
      > Your saved preferences (confirm or change):
      > 1. **DL framework**: PyTorch Lightning *(saved)* — or: PyTorch / JAX / TensorFlow / None
      > 2. **GNN library**: *(new)* — PyG / DGL / other
      > 3. **Compute**: SLURM cluster *(saved)* — or: Local / Cloud
      > ...
      > Reply "yes" to use these, or specify changes (e.g., "1: JAX, 2: PyG").

      **If no saved preferences exist**, format like:
      > Before setting up the project, a few preferences:
      > 1. **DL framework**: (a) PyTorch (b) PyTorch Lightning (c) JAX (d) TensorFlow (e) None
      > 2. **GNN library**: (a) PyG (b) DGL (c) other (d) none
      > ...
      > Reply with your choices (e.g., "1b, 2a, 3a") or "defaults" to use the first option for each.

   d. **Ask about PI meeting cadence.** Always include this question:
      > **PI meeting cadence**: How often should the PI review progress? The postdoc handles most check-ins autonomously.
      > (a) Every 2 cycles (b) Every 4 cycles *(recommended)* (c) Every 6 cycles (d) Every cycle (no postdoc autonomy)

   e. **Wait for the supervisor's reply.** Do NOT proceed until preferences are confirmed.

   f. **Save preferences to memory.** Write or update `supervisor_preferences.md` in the memory directory. **Merge** new answers with existing saved preferences — don't overwrite categories from prior projects that weren't asked about this time. Use this format:

      ```markdown
      ---
      name: supervisor_preferences
      description: Supervisor's default tool and environment preferences, accumulated across projects
      type: user
      ---

      ## <Category Name>
      <answer>

      ## <Category Name>
      <answer>
      ```

      Ensure `MEMORY.md` in the same directory includes the entry:
      `- [supervisor_preferences.md](supervisor_preferences.md) — Default tool/environment preferences for new research projects`
      If it already exists, leave it. If not, append it.

4. **Scaffold the project directory** under `projects/<name>/`:
   ```
   projects/<name>/
   ├── CLAUDE.md
   ├── state.yaml
   ├── plan.md
   ├── requirements.txt   ← pinned Python dependencies
   ├── .postdoc/           ← postdoc private notes (never read by student)
   │   ├── student_profile.md  ← copied from templates/student_profile_stub.md
   │   └── reviews/        ← per-cycle review records
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

5. **Create the project `CLAUDE.md`** using the confirmed preferences. Include an `## Environment & Tools` section with each preference as an actionable instruction:

   ```markdown
   # <Project Name>

   ## Research Topic
   <topic description from user>

   ## Environment & Tools
   - **<category>**: <choice> — <brief actionable instruction>
   - **<category>**: <choice> — <brief actionable instruction>
   ...

   ## Key Decisions
   (none yet)

   ## Domain Notes
   (to be filled during exploration)
   ```

   The actionable instruction tells the student HOW to use the preference. Examples:
   - **DL framework**: PyTorch Lightning — use `pl.LightningModule` for all models, `pl.Trainer` for training
   - **GNN library**: PyG (torch-geometric) — use `torch_geometric.data.Data` for graph structures
   - **Data format**: HDF5 — use `h5py` for reading, store processed tensors for fast loading
   - **Compute**: SLURM cluster — write batch scripts for training, never run GPU jobs interactively
   - **Experiment tracking**: Weights & Biases — log all runs with `wandb.init(project='<name>')`
   - **Visualization**: matplotlib + seaborn — seaborn for statistical plots, matplotlib for custom figures
   - **Inference framework**: vLLM — use for batched generation, HF transformers for tokenization only

6. **Create `state.yaml`** with (using the supervisor_cadence from the PI meeting cadence question):
   ```yaml
   phase: rd
   cycle: 1
   step: 0
   direction: 0
   velocity: 0
   mode: meeting
   last_checkin: null
   supervisor_cadence: 4   # or 2/6/1 based on PI's answer
   escalation: null
   notes: "Project created. In pre-project planning meeting."
   ```

7. **Copy `templates/cycle_notes.md`** to `cycles/cycle_01/notes.md`.

8. **Create `requirements.txt`** based on the confirmed preferences.

   Start with the base set:
   ```
   numpy
   pandas
   matplotlib
   scikit-learn
   jupyter
   ```

   Add packages corresponding to each confirmed preference. For example:
   - PyTorch Lightning → add `torch`, `torchvision`, `pytorch-lightning`
   - PyG → add `torch-geometric`
   - Weights & Biases → add `wandb`
   - seaborn → add `seaborn`

   Use your knowledge of Python packaging to determine the right pip package names. Do NOT pin versions yet — that happens after install.

9. **Create the virtual environment**: `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`. Then update `requirements.txt` with pinned versions: `pip freeze > requirements.txt`.

10. **Start a conversation about the project plan.** Ask the supervisor to describe their vision: the problem space, initial directions, possible outcomes, and any constraints. Distill this into `plan.md` together. This is the north star document — it should capture the research vision at a high level, not a task list.

11. **Confirm** to the user: show the created structure, the selected preferences, and explain that we are now in the **planning meeting** (Phase 1 of onboarding). The conversation should focus on defining the research vision, problem space, initial directions, and drafting `plan.md` together. Once the plan is approved, the student will proceed to Phase 2: a deep, autonomous literature review before the first Monday check-in.
