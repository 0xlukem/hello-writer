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

Phases:
1. Environment discovery (opencode models, providers)
2. Model assignment (smart defaults or custom)
3. Platform selection (blog, LinkedIn, X, Reels)
4. Digital Twin persona interview (15 questions with follow-ups)
5. Writing sample analysis (optional, extracts voice patterns)
6. Styleguide selection (Google Dev full/light, custom, none)
7. Config generation, template rendering, validation, summary

Closeout contract:
- End with a clear summary of what was configured.
- Provide the exact next step: Start OpenCode (`opencode`) and ask: "Run the content engine workflow to write a blog about [your topic]"
