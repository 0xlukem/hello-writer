# Changelog

All notable changes to **hello-writer**.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.1] - 2026-07-22

### Added

- Marked the 14 specialist agents as `hidden: true` in templates and
  `opencode.json`, keeping them out of the `@` autocomplete. The orchestrator
  still delegates to them via the Task tool.
- Added setup validation that `orchestrator.md` and `setup-orchestrator.md`
  render with `mode: primary`, guarding against regressions of the
  `default_agent` fallback issue.

### Fixed

- Set `orchestrator` and `setup-orchestrator` to `mode: primary` in
  `opencode.json` and in their agent templates. Both were configured as
  subagents, so `default_agent: "orchestrator"` was invalid: OpenCode fell
  back to the built-in `build` agent after install and the orchestrator was
  not selectable with Tab. Primary mode is required because both agents drive
  interactive flows (orchestrator checkpoints, setup interview). The 14
  specialist agents remain subagents delegated by the orchestrator.

### Documentation

- Documented primary vs subagent agent modes in the README Agent Architecture
  section.
- Added a troubleshooting entry for OpenCode falling back to `build` when
  `default_agent` points to a subagent.
- Noted Tab cycling between primary agents in Quick Start.

---

## [1.1.0] - 2026-07-14

### Added

- Added committed agent templates for the full 16-agent OpenCode engine under `templates/agents/`.
- Added new memory templates for `image-creator`, `linkedin-writer`, `x-thread-writer`, and `reel-script-writer`, bringing generated memory validation to 11 `.memory.md` files.
- Added `opencode.json` with `orchestrator` as the default agent and all specialist agents configured as subagents.
- Added `install.sh` as a thin alias for `setup.sh`.
- Added setup modes for quick setup, voice-only rebuilds, technical reconfiguration, render-only, validate-only, and dry-run previews.
- Added root output metadata generation and `.opencode/testing/checkpoint-transcripts/` setup for checkpoint evidence.

### Changed

- Migrated generated agent and memory artifacts from `agents/` to `.opencode/agents/` and updated setup, workflows, runtime guidelines, ignores, and docs to match.
- Reworked `setup.sh` into a mode-aware setup wizard with step labels, `NO_COLOR` support, prompt commands, write-plan confirmation, existing-config detection, and safer update/overwrite flows.
- Rebuilt the Digital Twin setup flow from a hardcoded persona-style wizard into reusable Brand, Audience, Positioning, Tone, Writing Mechanics, Platform Rules, Forbidden Patterns, Sample Analysis, Calibration, and Drift Detection sections.
- Improved writing sample handling with local pattern extraction and optional AI-assisted analysis that fails safely.
- Preserved existing Digital Twin voice memory by default in update and technical flows, with optional backups before overwrite.
- Strengthened setup validation for expected agent count, memory count, unresolved model placeholders, output metadata, and model IDs when `opencode models` is available.
- Updated runtime governance so `digital-twin` is mandatory, voice guidance is normalized through that phase, checkpoint transcripts live under `.opencode/testing/`, and history logging has a narrow factual-audit exception.
- Clarified the content workflow output contract for `final/`, `artifacts/`, `images/`, root `_meta.md`, skip behavior, image approval, blocked-session closeout, and memory update checkpoints.

### Documentation

- Improved README onboarding UX with project badges and a short "At a glance" summary.
- Made the first README viewport clearer about inputs, the 16-agent engine, generated Markdown output, and setup options.
- Clarified the different setup workflows: terminal setup, AI-guided OpenCode setup, and the `install.sh` convenience alias.
- Corrected the generated image filename example to match the `topic-slug-photo-1.png` convention.
- Replaced the generic `Unreleased` / `Planned` section with versioned notes for the current repository state.
- Moved `--dry-run` setup mode out of the planned roadmap because it already exists.

---

## [1.0.0] - 2026-05-08

### Added

- **16-agent content engine** — 15 content agents + 1 setup orchestrator
- **Dual setup paths**:
  - `./setup.sh` — Fast terminal wizard
  - `workflows/setup-workflow.md` — AI-guided conversational setup
- **Digital Twin persona system** — guided wizard for building a voice profile
- **Writing sample analysis** — setup can extract reusable voice patterns from samples
- **Template rendering system** — `{{VAR}}` placeholders render configured agent files
- **Config-driven architecture** — `config/content-engine.yml` as single source of truth
- **Confidence gates** — Research, SEO, content quality, and session confidence scores
- **Checkpoint system** — Approval-required decisions produce transcript artifacts
- **Memory loop** — `feedback-architect` proposes memory updates at session end; orchestrator checkpoints for engineer approval
- **Platform support** — Blog, LinkedIn, X/Twitter, and Reels
- **Image generation** — Two-step approval: propose concepts, await approval, then generate
- **Built-in styleguides** — Google Developer Docs (Full) and (Light)
- **Re-runnable setup** — Detects existing config and offers update, overwrite, or cancel
- **Blank memory templates** — Core agent memory files generated with section headers
- **Agent count validation** — Setup verifies generated agents
- **Model validation** — Checks chosen models against `opencode models` when available

### Architecture

- OpenCode-specific agent definitions with YAML frontmatter
- Workflow-driven execution via `workflows/content-engine.md`
- Runtime governance via `agent-runtime-guidelines.md`
- Per-user generated files excluded from git (`.gitignore`)
- Portfolio-ready with MIT License

---

## Notes

- hello-writer v1.0.0 is the first public release.
- It was extracted and generalized from a personal content engine (`writer-blogspot`).
- All personal voice data, model configs, and hardcoded references were removed and replaced with configurable templates.
