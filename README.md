# hello-writer

[![OpenCode](https://img.shields.io/badge/OpenCode-agent%20workflow-111827)](https://opencode.ai)
![Agents](https://img.shields.io/badge/agents-16-blue)
![Output](https://img.shields.io/badge/output-Markdown-2ea44f)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

Reusable multi-agent content engine for blogs, social posts, and video scripts.

`hello-writer` turns one topic into a governed content session: research, SEO,
voice adaptation, writing, editing, optional images, social repurposing, session
reporting, and memory proposals through OpenCode agents.

At a glance:

- Input: one topic plus optional platform, image, source, and voice guidance.
- Engine: 16 OpenCode agents generated from local templates and config.
- Output: Markdown content and audit artifacts under `output/YYYY-MM-DD_topic-slug/`.
- Setup: terminal wizard via `./setup.sh` or conversational setup inside OpenCode.

## Quick Start

```bash
git clone https://github.com/0xlukem/hello-writer.git hello-writer
cd hello-writer

./setup.sh

opencode
# Ask: Run the content engine workflow to write a blog about [your topic]
```

OpenCode starts with the `orchestrator` primary agent by default. Use Tab to
cycle between primary agents (`orchestrator`, `setup-orchestrator`, `build`,
`plan`); specialist agents are subagents the orchestrator delegates to.

If you naturally look for an install command, `./install.sh` is available as a
thin alias for `./setup.sh`.

## What It Does

Given a topic, the engine can:

1. Research and fact-check the topic.
2. Plan SEO structure and search intent.
3. Generate a platform-specific Voice Brief from the Digital Twin memory.
4. Write a long-form Markdown blog post.
5. Score and edit the draft through quality gates.
6. Propose and generate images after explicit approval.
7. Repurpose the approved blog into LinkedIn, X, and Reel script outputs.
8. Close with a session report, history entry, and proposed memory updates.

The workflow is intentionally governed: mandatory phases cannot be skipped,
conditional phases require recorded skip reasons, and reusable memory updates
require engineer approval.

## Installation

### Prerequisites

- OpenCode CLI installed.
- At least one OpenCode provider configured.

Useful checks:

```bash
opencode --version
opencode providers list
opencode models
```

### Setup Paths

There are two setup flows and one convenience alias. Both setup flows produce
the same local artifacts:
`config/content-engine.yml`, `.opencode/agents/*.md`,
`.opencode/agents/memory/*.md`, `output/`, and
`.opencode/testing/checkpoint-transcripts/`.

| Path | Best for | Command |
| --- | --- | --- |
| Terminal setup | Repeatable local setup with predictable prompts and validation. | `./setup.sh` |
| AI-guided setup | First-time users who want a deeper conversational voice interview. | `opencode`, then ask `Run the setup workflow` |
| Install alias | Users who expect an install entrypoint. Same behavior as terminal setup. | `./install.sh` |

Terminal setup is local and deterministic. AI-guided setup is better for richer
Digital Twin calibration, but it still follows the same setup contract.

## Setup Modes

`setup.sh` is the canonical entrypoint. Keep this table in sync with
`./setup.sh --help`.

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Full interactive setup wizard. |
| `./install.sh` | Alias for `./setup.sh`. Passes all args through. |
| `./setup.sh --quick` | Defaults plus a short voice interview and render. |
| `./setup.sh --voice` | Rebuild only `.opencode/agents/memory/digital-twin.memory.md`. |
| `./setup.sh --technical` | Models, platforms, styleguide, and render while preserving voice by default. |
| `./setup.sh --dry-run [mode]` | Preview planned writes without changing files. Combine with any mode. |
| `./setup.sh --render-only` | Re-render `.opencode/agents/*.md` from existing config/templates. |
| `./setup.sh --validate-only` | Validate generated config, agents, memory files, output metadata, and model ids when model discovery works. |
| `./setup.sh --help` | Show setup help. |

Prompt commands inside the setup wizard:

- `help`: show prompt help.
- `skip`: accept the default or leave an optional answer blank.
- `back`: return to the previous supported voice section.
- `quit`: exit without continuing.

Set `NO_COLOR=1` if your terminal should avoid colored output:

```bash
NO_COLOR=1 ./setup.sh --help
```

## Current Verified State

The current setup implementation is expected to pass:

```bash
bash -n setup.sh
bash -n install.sh
./setup.sh --validate-only
```

For a clean-install check, copy the repository to a temporary directory while
excluding generated artifacts, then run `NO_COLOR=1 ./setup.sh --quick` with
test answers. Expected results:

- 16 generated agent files in `.opencode/agents/`.
- 11 generated `.memory.md` files in `.opencode/agents/memory/`.
- `config/content-engine.yml`.
- `output/_meta.md`.
- No unresolved `{{MODEL_PLACEHOLDER}}` tokens in generated agents.
- No Digital Twin backup prompt during a first clean install.

Generated, user-specific artifacts are ignored by git:

- `.opencode/agents/`
- `.opencode/testing/`
- `config/content-engine.yml`
- `output/`

That keeps local personas, generated agents, and produced content out of the
shared repository.

## Running a Content Session

```bash
opencode
# Ask: Run the content engine workflow to write a blog about [your topic]
```

During a session, the orchestrator:

1. Confirms the topic, platforms, research needs, and image preference.
2. Creates `output/YYYY-MM-DD_topic-slug/`.
3. Delegates each phase to the correct specialist agent.
4. Applies confidence gates and retry loops.
5. Saves final content and artifacts as Markdown.
6. Runs mandatory closeout with report, feedback, and history logging.
7. Presents proposed memory updates for approval.

## Generated Files

Session output shape:

```text
output/
├── _meta.md
└── YYYY-MM-DD_topic-slug/
    ├── _meta.md
    ├── final/
    │   ├── blog.md
    │   ├── linkedin-post.md
    │   ├── x-thread.md
    │   └── reel-script.md
    ├── artifacts/
    │   ├── research-brief.md
    │   ├── seo-analysis.md
    │   ├── voice-brief-*.md
    │   ├── repurposer-output.md
    │   ├── editor-output.md
    │   └── feedback-architect.md
    └── images/
        ├── prompts.md
        └── topic-slug-photo-1.png
```

Not every session creates every optional file. Blog output is always enabled;
LinkedIn, X, Reels, and images depend on setup config and session approval.

## Agent Architecture

Agent modes follow OpenCode rules:

- `orchestrator` and `setup-orchestrator` are **primary** agents. They drive
  interactive sessions (checkpoints, setup interview), are selectable with
  Tab, and `orchestrator` is the `default_agent` in `opencode.json`.
- The 14 specialist agents below are **subagents**. The orchestrator delegates
  each phase to them via the Task tool. They are hidden from the `@`
  autocomplete (`hidden: true`) because they are not meant to be invoked
  directly, and they never drive a session themselves.

| Phase | Agent | Required | Purpose |
| --- | --- | --- | --- |
| 1 | orchestrator | Yes | Plans, delegates, checkpoints, and reports. |
| 2 | researcher | Conditional | Produces source-grounded research. |
| 3 | seo-expert | Conditional | Plans search intent and blog structure. |
| 4 | digital-twin | Yes | Converts voice memory and any user guidance into Voice Briefs. |
| 5 | blog-writer | Yes | Writes the long-form blog. |
| 6 | editor | Yes | Scores quality and triggers rewrite loops. |
| 7 | image-creator | Conditional | Proposes and generates approved blog images. |
| 8 | repurposer | Conditional | Creates platform briefs from the approved blog. |
| 9 | linkedin-writer | Conditional | Writes the LinkedIn post. |
| 10 | x-thread-writer | Conditional | Writes the X thread. |
| 11 | reel-script-writer | Conditional | Writes the Reel script. |
| 12 | editor-light | Conditional | Checks short-form outputs. |
| 13 | report-writer | Yes | Produces the final session report. |
| 14 | feedback-architect | Yes | Produces retrospective and memory proposals. |
| 15 | history-logger | Yes | Appends factual audit history. |

`digital-twin` is mandatory. If the user provides explicit voice guidance, that
guidance becomes input to `digital-twin`; it does not skip the phase.

## Governance and Checkpoints

Canonical runtime policy lives in `agent-runtime-guidelines.md`.

Important rules:

- Mandatory phases cannot be skipped.
- Conditional skips require a skip tag, risk assessment, safety guard, engineer
  approval, and transcript path.
- Research confidence can proceed, checkpoint, or block the workflow.
- Blog quality must reach `>= 85`; scores `70-84` loop back to the writer, and
  scores `< 70` block or require a checkpoint.
- Image generation requires approval before concepts and again before final
  generation.
- `feedback-architect` proposes memory updates only.
- `history-logger` may append factual audit entries to its own history memory
  without separate approval; it may not write editorial preferences elsewhere.

## Digital Twin

The Digital Twin is a reusable voice memory stored at:

```text
.opencode/agents/memory/digital-twin.memory.md
```

It captures:

- Brand snapshot.
- Audience.
- Positioning.
- Tone sliders.
- Writing mechanics.
- Platform rules.
- Forbidden language and claims.
- Sample analysis.
- Calibration notes.
- Drift detection rules.

Rebuild it with:

```bash
./setup.sh --voice
```

In update flows, setup preserves the existing Digital Twin by default and asks
before replacing it.

## Configuration

The generated configuration lives at:

```text
config/content-engine.yml
```

Common changes:

- Change model ids, then run `./setup.sh --render-only`.
- Enable or disable LinkedIn, X, Reels, or images, then re-render.
- Validate local setup with `./setup.sh --validate-only`.

If `opencode models` cannot be reached, setup still validates local files but
reports model availability as not verified.

## Troubleshooting

### `opencode CLI not found`

Install and configure OpenCode, then rerun setup.

```bash
opencode --version
opencode providers list
```

### Model availability not verified

Run:

```bash
opencode models
```

If the model list works manually, rerun:

```bash
./setup.sh --validate-only
```

### Agents are missing or not updated

Run:

```bash
./setup.sh --render-only
./setup.sh --validate-only
```

Expected generated agent count is 16 unless you deliberately extended the
workflow.

### OpenCode starts with `build` instead of the orchestrator

`default_agent` in `opencode.json` must point to a primary agent. If the
orchestrator is configured as a subagent, OpenCode falls back to the built-in
`build` agent with a warning, and the orchestrator is not selectable with Tab.

Confirm both places say `mode: primary` for `orchestrator`:

- `opencode.json` under `agent.orchestrator.mode`
- `.opencode/agents/orchestrator.md` frontmatter (fix templates, then run
  `./setup.sh --render-only`)

The same applies to `setup-orchestrator`. Specialist agents are subagents by
design; that part is expected.

### First setup asks for a Digital Twin backup

That should not happen in a clean install. If it does, check whether an old
`.opencode/agents/memory/digital-twin.memory.md` already exists.

## Maintenance Guide

Use this checklist when changing the engine.

### Adding or removing an agent

- Update `templates/agents/*.md.template`.
- Update model defaults and assignment in `setup.sh`.
- Update `render_agents` placeholder replacement if a new model variable exists.
- Update `validate_setup` expected agent list and count.
- Update `workflows/content-engine.md`.
- Update `agent-runtime-guidelines.md` phase matrix.
- Update this README's Agent Architecture table.

### Adding or changing a setup mode

- Update `parse_args`, `mode_label`, and step configuration in `setup.sh`.
- Update `usage()`.
- Update the Setup Modes table in this README.
- Add or adjust validation scenarios.

### Changing skip or memory rules

- Update `agent-runtime-guidelines.md`.
- Update `workflows/content-engine.md`.
- Update `templates/agents/orchestrator.md.template`.
- Update relevant specialist agent templates.
- Update this README's Governance and Checkpoints section.

### Changing generated artifacts

- Update `setup.sh` generation and validation.
- Update `.gitignore` if needed.
- Update the Generated Files section.
- Verify clean setup in a temporary directory.

## Development Checks

Recommended before handoff:

```bash
bash -n setup.sh
bash -n install.sh
./setup.sh --validate-only
NO_COLOR=1 ./setup.sh --dry-run --quick
```

For a full clean-install check, run `./setup.sh --quick` in a temporary copy of
the repo with generated artifacts excluded.

## License

MIT License. See `LICENSE`.
