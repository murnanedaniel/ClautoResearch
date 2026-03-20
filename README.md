# ClautoResearch

An AI Scientist built entirely on Claude Code. No frameworks, no multi-LLM orchestration — just Claude as a PhD student, you as the supervisor.

## How It Works

You give Claude a research topic. Claude works in **R&D cycles**, checking in with you via **LaTeX slide decks** — exactly like a PhD student meeting their supervisor twice a week. You review, redirect, and approve at each step. Nothing happens without your sign-off.

Each cycle:

```
Mon morning: Check-in slides
  Present results from last Wed→Sun
  Discuss plan for Mon-Tue exploration

Mon → Tue: Exploration
  Literature, prototyping, thinking
  Student has autonomy

Wed morning: Check-in slides
  Present Mon-Tue findings
  Sign off on Wed→Sun execution plan

Wed → Sun: Execution
  Build, run experiments, collect results
  Approved plan is append-only
```

**Direction** (0-100): How defined is the research question? Start broad, narrow over time.
**Velocity** (0-100): How fast are we moving? Start slow (reading/thinking), accelerate as direction solidifies.

When results are ready, a separate **writing phase** drafts the paper — and can drop back into R&D when gaps appear.

## Try It

**CLI:**
```bash
git clone git@github.com:murnanedaniel/ClautoResearch.git && cd ClautoResearch && claude --dangerously-skip-permissions
```

**VS Code:** Clone the repo, open it in VS Code with the [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code), and open the Claude panel.

Then type: `/new-project "Your research topic"`

That's it. Claude takes it from there.

## How It Works (details)

**Prerequisites**: [Claude Code](https://claude.com/claude-code) installed, `pdflatex` available.

`/new-project` scaffolds a project under `projects/` and starts a conversation about the project plan. From there, just talk to Claude — it reads the system instructions from `CLAUDE.md`, picks up project state from `state.yaml`, and knows what to do. It will work through the R&D cycle steps and automatically produce slide decks at each gate for your review.

Two explicit commands:
- `/new-project "topic"` — scaffold a new research project
- `/write` — switch to paper-writing mode (when you're ready)

Everything else (literature search, experiment design, coding, running studies, producing check-in slides) happens naturally as Claude follows the workflow.

A **hook** enforces check-in discipline: if Claude is past a gate point without having produced slides, it gets a reminder injected into its context before it can do anything else. The student always shows up with a deck.

## Project Structure

```
ClautoResearch/
├── CLAUDE.md                    # System instructions (the "constitution")
├── .claude/
│   ├── skills/                  # Slash commands
│   │   ├── new-project/         #   /new-project — scaffold a research project
│   │   └── write/               #   /write — enter writing phase
│   ├── hooks/
│   │   └── enforce_checkin.sh   #   Ensures slides are produced at gate points
│   └── settings.json            #   Hook configuration
├── templates/
│   ├── checkin_template.tex     # Beamer slide deck template
│   └── cycle_notes.md           # Cycle notes/scratchpad template
├── literature/                  # System-level literature reviews
└── projects/                    # Your research projects live here
    └── <project-name>/
        ├── CLAUDE.md            # Project-specific context
        ├── state.yaml           # Current cycle/step/direction/velocity
        ├── plan.md              # Long-running project plan (north star)
        ├── src/                 # Persistent code (promoted from cycles)
        │   ├── data/            # Data loading, preprocessing
        │   ├── models/          # Model definitions
        │   └── utils/           # Shared utilities
        ├── literature/          # Project-specific references
        ├── cycles/              # cycle_01/, cycle_02/, ...
        │   └── cycle_NN/
        │       ├── notes.md     # Cycle scratchpad (from template)
        │       ├── slides/      # Check-in PDFs
        │       ├── code/        # Experiments (notebooks early, scripts later)
        │       └── results/     # Outputs, plots, metrics
        └── paper/               # Paper drafts (writing phase)
```

The system (root) defines *how* research is done. Each project (under `projects/`) is a specific research effort with its own state, cycles, and results.

## Design Philosophy

- **Claude-native**: Uses Claude Code skills, CLAUDE.md hierarchy, and hooks — not a Python orchestration framework
- **Supervisor in the loop**: Every phase gate is a slide deck review. No auto-approve mode
- **Minimal by design**: One model, one repo, two slash commands, one hook
- **Real research workflow**: Modeled on how PhD advisors actually mentor students, not on pipeline diagrams

## License

MIT
