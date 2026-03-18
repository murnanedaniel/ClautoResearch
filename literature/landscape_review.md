# AI Scientist Landscape Review

*Last updated: 2026-03-18*

## Overview

This document surveys the current landscape of autonomous AI research systems — tools that use LLMs to automate parts (or all) of the scientific research pipeline: literature review, idea generation, experiment design/execution, and paper writing.

**Our goal**: Build an AI Scientist that uses **only Claude out-of-the-box** with careful prompting, hooks, skills, and Claude Code tooling — no sprawling multi-LLM orchestration frameworks.

---

## Major Projects

### 1. AI Scientist v1 & v2 (Sakana AI) ⭐ Most prominent

- **Repo**: [github.com/SakanaAI/AI-Scientist-v2](https://github.com/SakanaAI/AI-Scientist-v2)
- **Papers**: [arXiv 2408.06292](https://arxiv.org/abs/2408.06292) (v1), [arXiv 2504.08066](https://arxiv.org/abs/2504.08066) (v2)
- **What**: End-to-end: idea generation → code writing → experiment execution → visualization → LaTeX manuscript. v2 produced first fully AI-generated paper accepted at ICLR 2025 workshop.
- **Architecture**:
  - v1: Template-based pipeline with fixed stages. Requires human-authored code templates.
  - v2: Progressive agentic tree search guided by experiment manager. Template-free. VLM feedback on plots. Best-first tree search.
- **LLMs**: Claude 3.5 Sonnet (experiments), GPT-4o, o1-preview (writeup), o3-mini (plots), Gemini
- **Cost**: $15-30/paper
- **Limitations**: Lower success rates in v2 due to broader exploration. Security risks from executing LLM-written code. ML-only domains. Independent eval ([arXiv 2502.14297](https://arxiv.org/abs/2502.14297)) found "bold claims, mixed results."

### 2. AutoResearchClaw (AIMING Lab, UNC Chapel Hill)

- **Repo**: [github.com/aiming-lab/AutoResearchClaw](https://github.com/aiming-lab/AutoResearchClaw)
- **What**: 23-stage pipeline turning a single idea into conference-ready LaTeX paper. "Chat an Idea. Get a Paper."
- **Architecture**: 8 phases, 23 stages as state machine:
  - A: Scoping → B: Literature (OpenAlex/Semantic Scholar/arXiv) → C: Synthesis (multi-agent hypothesis generation) → D: Design (hardware-aware code gen) → E: Execution (sandbox with self-healing, up to 10 repair rounds) → F: Analysis (autonomous PIVOT/REFINE) → G: Writing (outline, draft, peer review, revision) → H: Finalization (quality gate, LaTeX export, citation verification)
- **Key features**:
  - 4-layer citation verification (kills hallucinated refs)
  - Multi-agent debate for hypothesis refinement
  - Domain-aware profiles (20+ YAML configs for ML, physics, chemistry, biology, economics)
  - Self-evolution via MetaClaw (lessons from failures, 30-day decay)
  - Gate stages requiring human approval (unless `--auto-approve`)
- **LLMs**: OpenAI primary (gpt-4o default), Anthropic via adapter, any OpenAI-compatible
- **Limitations**: Fallback chains mask failures (can produce output based entirely on LLM hallucinations). Citation verification is probabilistic (Jaccard word-overlap). Experiments limited to 300s sandbox runs. Domain profiles heavily ML-weighted.

### 3. AI-Researcher (HKUDS, Hong Kong University)

- **Repo**: [github.com/HKUDS/AI-Researcher](https://github.com/HKUDS/AI-Researcher)
- **Paper**: [arXiv 2505.18705](https://arxiv.org/abs/2505.18705) — NeurIPS 2025 Spotlight
- **What**: 6-stage pipeline: Literature Review → Idea Generation → Algorithm Design → Validation & Refinement → Result Analysis → Manuscript Creation
- **LLMs**: LiteLLM (flexible); documented with Gemini 2.5 Pro
- **Key innovations**: Hierarchical writing. Production deployment at [novix.science](https://novix.science/chat). Scientist-Bench evaluation across 22 papers.

### 4. FutureHouse (Robin, Kosmos, PaperQA2)

- **URLs**: [futurehouse.org](https://www.futurehouse.org/), [github.com/Future-House/paper-qa](https://github.com/Future-House/paper-qa)
- **What**: 10-year moonshot for semi-autonomous scientific AI. Suite of specialized agents.
- **Key systems**:
  - **PaperQA2**: RAG literature agent, superhuman on scientific search. Open source.
  - **Robin**: Multi-agent system integrating literature, synthesis, and data analysis agents
  - **Kosmos**: Next-gen AI scientist using "structured world models." Processes 1,500 papers per run.
- **Key innovations**: Bridges to wet-lab biology. Spun out Edison Scientific ($70M raise, Nov 2025).
- **Limitations**: Kosmos not fully open source. Physical experiments still require humans.

### 5. Karpathy's autoresearch

- **Repo**: [github.com/karpathy/autoresearch](https://github.com/karpathy/autoresearch)
- **What**: Minimalist (630 LOC) framework for autonomous ML experimentation. Agent modifies training code, trains 5 min, checks if validation improved, repeats. ~12 experiments/hour.
- **LLMs**: Any coding agent (designed for Claude Code, Cursor)
- **Philosophy**: Radical simplicity. One GPU, one file, one metric. No paper writing, no lit review.
- **Results**: 19% validation improvement reported. Agent-optimized small model beat manually-configured larger model.

### 6. Google AI Co-Scientist

- **Paper**: [arXiv 2502.18864](https://arxiv.org/abs/2502.18864)
- **What**: Multi-agent "generate, debate, evolve" system for hypothesis generation. Biomedical focus.
- **LLMs**: Gemini 2.0
- **Validated**: Drug repurposing predictions confirmed in wet-lab experiments.
- **Limitations**: Not open source. Not end-to-end autonomous. Expert-in-the-loop design.

### 7. Other Notable Projects

| Project | What | URL |
|---------|------|-----|
| **Autoscience Carl** | First AI to produce peer-reviewed research (ICLR 2025 workshop). Closed source. | [autoscience.ai](https://www.autoscience.ai/) |
| **Agent Laboratory** | End-to-end research workflow with specialized agents | [github.com/SamuelSchmidgall/AgentLaboratory](https://github.com/SamuelSchmidgall/AgentLaboratory) |
| **MLR-Copilot** | RL-tuned idea generation + HuggingFace integration | [arXiv 2408.14033](https://arxiv.org/abs/2408.14033) |
| **SciAgents (MIT)** | Knowledge graph-driven discovery for materials science | [github.com/lamm-mit/SciAgentsDiscovery](https://github.com/lamm-mit/SciAgentsDiscovery) |
| **ChemCrow** | Chemistry agent with 18 tools, IBM automated lab integration | [arXiv 2304.05376](https://arxiv.org/abs/2304.05376) |
| **OpenAI Deep Research** | o3-powered research synthesis (not full automation) | Commercial, $200/mo |

---

## Key Surveys & Meta-Resources

- **"From Automation to Autonomy: LLMs in Scientific Discovery"** (EMNLP 2025): [Awesome list](https://github.com/HKUST-KnowComp/Awesome-LLM-Scientific-Discovery)
- **"Towards Scientific Intelligence: LLM-based Scientific Agents"**: [arXiv 2503.24047](https://arxiv.org/html/2503.24047v1)
- **"Deep Research: A Survey of Autonomous Research Agents"**: [arXiv 2508.12752](https://arxiv.org/html/2508.12752v1)
- **Evaluation of Sakana's AI Scientist**: [arXiv 2502.14297](https://arxiv.org/abs/2502.14297)

---

## Landscape Patterns & Lessons for ClautoResearch

### What works
1. **Multi-agent debate/review**: Nearly every successful system uses competing agent perspectives (skeptic, enthusiast, methodologist) for hypothesis refinement and self-critique
2. **Gate stages with human approval**: AutoResearchClaw's gate pattern is good — critical decision points should optionally involve the human
3. **Citation verification**: Hallucinated references are a universal problem. Real API-backed verification is essential
4. **Sandbox execution with self-healing**: Iterative code repair (up to N rounds) is standard and effective
5. **Domain profiles**: YAML-based domain configs scale well

### What's broken
1. **Multi-LLM orchestration complexity**: Most systems use 3-5 different LLMs for different stages. This adds fragility, cost unpredictability, and maintenance burden
2. **Fallback chains that mask failure**: AutoResearchClaw's pattern of falling back to LLM-generated placeholders means you can produce confident-looking garbage
3. **Shallow experiments**: 300-second sandbox timeouts limit what you can actually discover
4. **ML-only tunnel vision**: Almost all systems only work for computational ML research
5. **No real novelty detection**: "Novelty checks" via Semantic Scholar are crude at best

### Our differentiator: Claude-native design
No existing system is built Claude-first. They all use Claude as one of many LLM backends behind an OpenAI-compatible adapter. We can:

1. **Use Claude Code's native tooling**: hooks, skills, slash commands, MCP servers — no custom orchestration framework needed
2. **Leverage extended thinking**: Claude's chain-of-thought for complex reasoning about hypotheses and experimental design
3. **Single-model simplicity**: One model, one API, one billing relationship. No adapter layers.
4. **Claude's strengths**: Strong at code generation, careful reasoning, and following complex instructions — exactly what research automation needs
5. **Hooks for human-in-the-loop**: Claude Code hooks can implement gate stages natively
6. **Skills for research phases**: Each research phase (lit review, ideation, experimentation, writing) can be a Claude Code skill

---

## Architecture Ideas for ClautoResearch

Based on this review, a Claude-native AI scientist could look like:

```
Research Idea (user input)
    │
    ▼
┌─────────────────────┐
│  Phase 1: Scoping   │  ← Claude extended thinking for problem decomposition
│  (skill: /scope)    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Phase 2: Literature │  ← Semantic Scholar/arXiv MCP servers + PaperQA2-style RAG
│  (skill: /litreview) │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Phase 3: Ideation   │  ← Multi-perspective prompting (no multi-agent needed!)
│  (skill: /ideate)    │
└─────────┬───────────┘
          │
          ▼  [GATE: human approval]
┌─────────────────────┐
│  Phase 4: Design     │  ← Experiment design + code generation
│  (skill: /design)    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Phase 5: Execute    │  ← Sandbox execution with iterative repair
│  (skill: /experiment)│
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Phase 6: Analyze    │  ← Results analysis + pivot/continue decision
│  (skill: /analyze)   │
└─────────┬───────────┘
          │
          ▼  [GATE: human approval]
┌─────────────────────┐
│  Phase 7: Write      │  ← Paper drafting with self-review
│  (skill: /write)     │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Phase 8: Finalize   │  ← Citation verification + LaTeX export
│  (skill: /finalize)  │
└─────────────────────┘
```

Key design principles:
- **Each phase = a Claude Code skill** (not a separate agent or LLM call)
- **Hooks for gates** (pre-approval before experiment execution and paper writing)
- **MCP servers for external APIs** (Semantic Scholar, arXiv, CrossRef)
- **Single Claude model throughout** — use prompting, not model-switching, for different capabilities
- **Artifacts stored as files** in a structured project directory
- **Git-tracked state** — every phase commits its outputs, enabling resume/rollback
