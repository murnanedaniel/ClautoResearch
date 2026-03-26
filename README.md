# ClautoResearch

An AI Scientist built entirely on Claude Code. No frameworks, no multi-LLM orchestration — just Claude as a PhD student, you as the supervisor.

## How It Works

![ClautoResearch Workflow](assets/workflow.gif)

You give Claude a research topic. Claude works in **R&D cycles**, checking in via **LaTeX slide decks** — exactly like a PhD student meeting their supervisor twice a week. A configurable review layer controls who reviews at each gate: you directly, a postdoc subagent, or the student's own self-review.

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

## Review Modes

At project creation, you choose a **review mode** that controls how gate-point check-ins work. This enables ablation studies comparing different levels of human oversight:

| Mode | Gate reviewer | PI involvement | Use case |
|------|-------------|---------------|----------|
| `pi_direct` | None — PI reviews directly | Every gate (Mon+Wed) | Maximum oversight |
| `self_review` | Student self-reviews via checklist | PI at cadence (e.g. every 4 cycles) | Moderate oversight |
| `postdoc` | Postdoc subagent | PI at cadence | Balanced autonomy + quality **(default)** |
| `autonomous` | Postdoc subagent | Never (except initial planning) | Maximum autonomy |

**All modes produce slides at every gate.** The slide-production rhythm is constant — only the review mechanism changes. This ensures comparable artifacts across configurations.

### `pi_direct` — Human reviews everything

The original hands-on mode. Every Monday and Wednesday gate stops for the PI. No postdoc, no self-review. This is the baseline for ablation: maximum human control.

### `self_review` — Student reviews own work

At each gate, the student reviews slides against a structured checklist (methodology, scope, literature, results, alignment, presentation). The PI only meets at a configured cadence (e.g. every 4 cycles). Tests whether the student can self-correct without external feedback.

### `postdoc` — Postdoc subagent reviews (default)

A postdoc subagent (spawned via the Agent tool) conducts full reviews at every gate: reads slides, probes methodology, asks hard questions, and decides whether to approve, request revisions, or escalate to the PI. The postdoc has bounded authority — can adjust direction/velocity by ±15 per review. The PI meets at a configured cadence, or when escalated.

The postdoc maintains **private notes** in `.postdoc/` — candid observations about the student's patterns, strengths, and areas to watch. These are architecturally private (the student subagent cannot see them). At PI meeting cycles, the postdoc prepares a brief for the PI.

### `autonomous` — No human involvement after planning

The postdoc reviews at every gate but the student never stops for a PI meeting. The postdoc is the final authority with no escalation path. Tests whether the student+postdoc pair can run a complete project end-to-end without human intervention.

### Escalation

In `postdoc` and `self_review` modes, either the student or the postdoc can trigger an **immediate PI meeting** at any gate point — not just at scheduled cadences. This handles situations that need PI judgment: major pivots, fundamental approach questions, or the student being stuck.

## Try It

**CLI:**
```bash
git clone git@github.com:murnanedaniel/ClautoResearch.git && cd ClautoResearch && claude --dangerously-skip-permissions
```

**VS Code:** Clone the repo, open it in VS Code with the [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code), and open the Claude panel.

Then type: `/new-project "Your research topic"`

You'll be asked for tool preferences and review mode. That's it — Claude takes it from there.

## How It Works (details)

**Prerequisites**: [Claude Code](https://claude.com/claude-code) installed, `pdflatex` available.

`/new-project` scaffolds a project under `projects/`, asks about review mode and PI meeting cadence, and starts a planning conversation. From there, just talk to Claude — it reads the system instructions from `CLAUDE.md`, picks up project state from `state.yaml`, and knows what to do. It will work through the R&D cycle steps and automatically produce slide decks at each gate.

Two explicit commands:
- `/new-project "topic"` — scaffold a new research project
- `/write` — switch to paper-writing mode (when you're ready)

Everything else (literature search, experiment design, coding, running studies, producing check-in slides, spawning postdoc reviews) happens naturally as Claude follows the workflow.

**Hooks** enforce the workflow:
- **Check-in hook** (`enforce_checkin.sh`) — ensures slides are produced at gate points; injects review-mode-specific context (self-review checklist, postdoc spawn instructions, or PI meeting context with postdoc brief)
- **Stop hook** (`stop_hook.sh`) — keeps Claude working autonomously through entire phases; dispatches gate logic based on review mode; manages the postdoc → PI meeting → working mode transitions

## Project Structure

```
ClautoResearch/
├── CLAUDE.md                    # System instructions (the "constitution")
├── .claude/
│   ├── skills/                  # Slash commands
│   │   ├── new-project/         #   /new-project — scaffold a research project
│   │   └── write/               #   /write — enter writing phase
│   ├── hooks/
│   │   ├── enforce_checkin.sh   #   Gate enforcement + context injection
│   │   └── stop_hook.sh         #   Autonomous work enforcement
│   └── settings.json            #   Hook configuration
├── templates/
│   ├── checkin_template.tex     # Beamer slide deck template (regular check-ins)
│   ├── pi_checkin_template.tex  # PI meeting slide template (multi-cycle summary)
│   ├── postdoc_prompt.md        # Postdoc subagent system prompt
│   ├── self_review_prompt.md    # Self-review checklist
│   ├── student_profile_stub.md  # Initial postdoc private notes template
│   └── cycle_notes.md           # Cycle notes/scratchpad template
├── literature/                  # System-level literature reviews
└── projects/                    # Your research projects live here
    └── <project-name>/
        ├── CLAUDE.md            # Project-specific context
        ├── state.yaml           # Cycle, step, direction, velocity, review_mode
        ├── plan.md              # Long-running project plan (north star)
        ├── .postdoc/            # Postdoc private notes (student cannot read)
        │   ├── student_profile.md  # Accumulated observations
        │   ├── pi_brief.md      # Brief for PI meetings
        │   └── reviews/         # Per-cycle review records
        ├── src/                 # Persistent code (promoted from cycles)
        │   ├── data/            # Data loading, preprocessing
        │   ├── models/          # Model definitions
        │   └── utils/           # Shared utilities
        ├── literature/          # Project-specific references
        ├── cycles/              # cycle_01/, cycle_02/, ...
        │   └── cycle_NN/
        │       ├── notes.md     # Cycle scratchpad (from template)
        │       ├── slides/      # Check-in PDFs (monday + wednesday)
        │       ├── code/        # Experiments (notebooks early, scripts later)
        │       └── results/     # Outputs, plots, metrics
        └── paper/               # Paper drafts (writing phase)
```

The system (root) defines *how* research is done. Each project (under `projects/`) is a specific research effort with its own state, cycles, and results.

## State Management

Each project tracks its state in `state.yaml`:

```yaml
phase: rd              # rd | writing
cycle: 1               # Current cycle number
step: 0                # 0=lit review, 1=explore, 2=design, 3=setup, 4=GSW, 5=PoC
direction: 0           # 0-100, how defined is the research question
velocity: 0            # 0-100, how fast are we moving
mode: working          # working | self_review | postdoc_review | meeting
review_mode: postdoc   # pi_direct | self_review | postdoc | autonomous
supervisor_cadence: 4  # PI meets every N cycles (for self_review/postdoc modes)
escalation: null       # Set to reason string when escalated to PI
```

## Design Philosophy

- **Claude-native**: Uses Claude Code skills, CLAUDE.md hierarchy, and hooks — not a Python orchestration framework
- **Configurable oversight**: Four review modes from full PI control to full autonomy — same slide artifacts, different review mechanisms
- **Ablation-ready**: Constant slide production across modes enables direct comparison of research quality under different oversight levels
- **Real research workflow**: Modeled on how PhD advisors actually mentor students, not on pipeline diagrams
- **Minimal by design**: One model, one repo, two slash commands, two hooks

## License

MIT
