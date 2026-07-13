# Setup Workflow: setup-workflow

Mandatory policy reference: `agent-runtime-guidelines.md`

1. setup-orchestrator

Workflow intent:
- One-time or reconfiguration setup for hello-writer.
- Guides the user through a conversational interview to generate their personalized content engine.

Workflow-specific execution contract:
- This workflow generates the `config/content-engine.yml` file and all `.opencode/agents/` definitions.
- It can be run multiple times (reconfiguration) and will detect existing config.
- The setup-orchestrator is a single agent that handles all setup phases conversationally.
- Output: `config/content-engine.yml`, `.opencode/agents/*.md`, `.opencode/agents/memory/*.md`, `output/` directory, and `.opencode/testing/checkpoint-transcripts/`.
- Terminal setup uses `./setup.sh` as the canonical entrypoint. `./install.sh` is only a thin alias for users who look for an install command.
- Do not write files until the user has reviewed a clear write plan.
- Dry-run mode must report planned writes without saying files are ready or created.
- In update flows, preserve existing Digital Twin voice memory by default.

Phases:
1. Environment discovery (opencode version, models, providers)
2. Existing setup detection (new, update, overwrite, cancel)
3. Model assignment (smart defaults or custom)
4. Platform and feature selection (Blog, LinkedIn, X, Reels, images)
5. Voice Builder:
   - Voice 1/9 Brand Snapshot
   - Voice 2/9 Audience
   - Voice 3/9 Positioning
   - Voice 4/9 Tone Sliders
   - Voice 5/9 Writing Mechanics
   - Voice 6/9 Platform Rules
   - Voice 7/9 Forbidden Patterns
   - Voice 8/9 Writing Samples
   - Voice 9/9 Preview & Calibration
6. Writing sample analysis:
   - Local analysis is always available for provided sample files.
   - AI-assisted analysis is optional and must fail safely.
7. Styleguide selection (Google Dev full/light, custom, none)
8. Write plan confirmation (config, voice memory, agents, preserved files, overwritten files)
9. Config generation, template rendering, memory generation, validation, summary

Validation must confirm:
- 16 generated agent files.
- 11 generated `.memory.md` files.
- `output/_meta.md`.
- No unresolved model placeholders in generated agents.
- Model ids only when `opencode models` succeeds; otherwise report model availability as not verified.

Closeout contract:
- End with a clear summary of what was configured.
- Provide the exact next step: Start OpenCode (`opencode`) and ask: "Run the content engine workflow to write a blog about [your topic]"
