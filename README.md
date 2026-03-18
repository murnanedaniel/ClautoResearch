# ClautoResearch

An AI Scientist built entirely on Claude Code. No frameworks, no multi-LLM orchestration — just Claude as a PhD student, you as the supervisor.

## How It Works

You give Claude a research topic. Claude works in **R&D cycles**, checking in with you via **LaTeX slide decks** — exactly like a PhD student meeting their supervisor twice a week. You review, redirect, and approve at each step. Nothing happens without your sign-off.

Each cycle:

```
Mon → Wed                          Wed → Fri
─────────────────────────          ─────────────────────────
1. Explore literature              3. Set up environment
2. Design minimal study            4. Get something working
        │                          5. Run proof-of-concept
        ▼                                  │
  📊 Wednesday slides                      ▼
  (supervisor reviews)              📊 Friday slides
                                   (supervisor reviews,
                                    sets direction/velocity)
```

**Direction** (0-100): How defined is the research question? Start broad, narrow over time.
**Velocity** (0-100): How fast are we moving? Start slow (reading/thinking), accelerate as direction solidifies.

When results are ready, a separate **writing phase** drafts the paper — and can drop back into R&D when gaps appear.

## Quick Start

**Prerequisites**: [Claude Code](https://claude.com/claude-code) installed, `pdflatex` available.

```bash
git clone git@github.com:murnanedaniel/ClautoResearch.git
cd ClautoResearch
```

Then in Claude Code:

```
/new-project "Your research topic here"
```

This scaffolds a project under `projects/`. Then:

```
/rd-cycle       # Run the next R&D step
/checkin        # Generate a check-in slide deck for review
/write          # Enter paper-writing mode (when ready)
```

That's it. Claude reads the system instructions from `CLAUDE.md`, picks up project state from `projects/<name>/state.yaml`, and knows what to do.

## Project Structure

```
ClautoResearch/
├── CLAUDE.md                    # System instructions (the "constitution")
├── .claude/skills/              # Slash commands
│   ├── new-project/SKILL.md     #   /new-project — scaffold a research project
│   ├── rd-cycle/SKILL.md        #   /rd-cycle — run next cycle step
│   ├── checkin/SKILL.md         #   /checkin — generate slide deck
│   └── write/SKILL.md           #   /write — enter writing phase
├── templates/
│   └── checkin_template.tex     # Beamer slide deck template
├── literature/                  # System-level literature reviews
└── projects/                    # Your research projects live here
    └── <project-name>/
        ├── CLAUDE.md            # Project-specific context
        ├── state.yaml           # Current cycle/step/direction/velocity
        ├── literature/          # Project-specific references
        ├── cycles/              # cycle_01/, cycle_02/, ...
        │   └── cycle_NN/
        │       ├── slides/      # Check-in PDFs
        │       ├── code/        # Experiment code
        │       └── results/     # Outputs and plots
        └── paper/               # Paper drafts (writing phase)
```

The system (root) defines *how* research is done. Each project (under `projects/`) is a specific research effort with its own state, cycles, and results.

## Design Philosophy

- **Claude-native**: Uses Claude Code skills, CLAUDE.md hierarchy, and hooks — not a Python orchestration framework
- **Supervisor in the loop**: Every phase gate is a slide deck review. No auto-approve mode
- **Minimal by design**: One model, one repo, four slash commands
- **Real research workflow**: Modeled on how PhD advisors actually mentor students, not on pipeline diagrams

## License

MIT
