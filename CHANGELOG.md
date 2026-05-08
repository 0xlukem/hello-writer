# Changelog

All notable changes to **hello-writer**.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-08

### Added

- **16-agent content engine** — 15 content agents + 1 setup orchestrator
- **Dual setup paths**:
  - `./setup.sh` — Fast terminal wizard (~2 min)
  - `workflows/setup-workflow.md` — AI-guided conversational setup (~5-10 min)
- **Digital Twin persona system** — 15-question wizard that builds a voice profile
- **Automatic writing sample analysis** — AI-guided setup reads samples and extracts voice patterns (hooks, tone, CTAs, forbidden words)
- **Template rendering system** — `{{VAR}}` placeholders in `templates/agents/` render to `agents/` with user-chosen models
- **Config-driven architecture** — `config/content-engine.yml` as single source of truth
- **Confidence gates** — Research, SEO, content quality (0-100), and session confidence scores
- **Checkpoint system** — Approval-required decisions produce transcript artifacts
- **Memory loop** — `feedback-architect` proposes memory updates at session end; orchestrator checkpoints for engineer approval
- **Platform support** — Blog (always), LinkedIn, X/Twitter, Reels (toggleable)
- **Image generation** — Two-step approval: propose 3 concepts, await approval, then generate
- **Built-in styleguides** — Google Developer Docs (Full) and (Light)
- **Demo persona** — Alex Rivera (developer-educator) included as starting example
- **Re-runnable setup** — Detects existing config, offers update / overwrite / cancel
- **Blank memory templates** — 7 agent memory files auto-generated with section headers
- **Agent count validation** — Setup verifies all 16 agents are rendered
- **Model validation** — Checks chosen models against `opencode models`

### Architecture

- OpenCode-specific agent definitions with YAML frontmatter
- Workflow-driven execution via `workflows/content-engine.md`
- Runtime governance via `agent-runtime-guidelines.md`
- Per-user generated files excluded from git (`.gitignore`)
- Portfolio-ready with MIT License

---

## [Unreleased]

### Planned

- Python/LangChain port for Claude/Anthropic (provider-agnostic)
- Newsletter writer agent (Substack, ConvertKit)
- Medium writer agent
- Additional built-in styleguides (AP Style, Chicago Manual)
- Multi-language persona support
- `--dry-run` flag for setup.sh
- Reconfigure workflow for partial updates
- Web UI for non-technical users

---

## Notes

- hello-writer v1.0.0 is the first public release.
- It was extracted and generalized from a personal content engine (`writer-blogspot`).
- All personal voice data, model configs, and hardcoded references were removed and replaced with configurable templates.
