# Content Engine: content-engine

Mandatory policy reference: `agent-runtime-guidelines.md`

1. orchestrator
2. researcher
3. seo-expert
4. digital-twin
5. blog-writer
6. editor
7. image-creator (conditional)
8. repurposer (conditional)
9. linkedin-writer (conditional)
10. x-thread-writer (conditional)
11. reel-script-writer (conditional)
12. editor-light (conditional)
13. report-writer
14. feedback-architect
15. history-logger

Workflow intent:
- This workflow is for multi-platform content creation from a single topic.
- Rule authority lives in `agent-runtime-guidelines.md`.

Workflow-specific execution contract:
- Content policy: workflow applies only to text-based content (blog, social, scripts).
- Output format: all content saved as Markdown in `output/YYYY-MM-DD_topic/`.
  - `final/` - delivery-ready assets (blog.md, linkedin-post.md, x-thread.md, reel-script.md)
  - `artifacts/` - supporting documents (research-brief.md, seo-analysis.md, voice-brief-*.md, repurposer-output.md, editor-output.md, feedback-architect.md)
  - `images/` - AI-generated blog images (`<topic-slug>-photo-1.png`, etc.)
  - `_meta.md` - session report at the root of the topic folder
- Confidence gate policy:
  - `researcher` must return `research_confidence` (`high|medium|low`).
  - `seo-expert` must return `seo_opportunity_confidence` (`high|medium|low`).
  - `editor` must return `content_quality_score` (`0-100`).
  - `feedback-architect` must return `session_confidence` (`high|medium|low`).
  - Confidence rubric is defined in `agent-runtime-guidelines.md`.
  - If `research_confidence` is `medium`, orchestrator must checkpoint.
  - If `research_confidence` is `low`, orchestrator must block.
  - If `content_quality_score` < 70, orchestrator must block or loop.
- Loop rule:
  - If `editor` returns score < 85 (blog) or < 75 (short-form), route back to respective writer.
  - Blog: up to 2 retry loops.
  - Short-form: up to 1 retry loop.
  - If retry cap reached, checkpoint with rewrite-or-approve decision.
- Skip behavior comes from runtime guidelines.
  - `researcher` may auto-skip only with `NO_RESEARCH_NEEDED`.
  - `seo-expert` may auto-skip only with `NO_SEO_NEEDED`.
  - `digital-twin` may auto-skip only with `NO_VOICE_ADAPTATION` (rare, only when user explicitly provides full voice guidance).
  - `image-creator` may auto-skip only with `NO_IMAGES` or `BLOG_ONLY`.
  - `repurposer` and platform writers may auto-skip only with `BLOG_ONLY` or `NO_SHORTFORM`.
- Image generation policy:
  - `image-creator` runs only after `editor` returns `content_quality_score` >= 85.
  - Orchestrator must checkpoint with engineer before `image-creator` runs: "Do you want images for this blog post?"
  - `image-creator` must propose 3 concepts and await engineer approval before generating.
  - If image generation fails, agent must save prompts to `images/prompts.md` and return `FAIL` with risk noted.

Closeout contract:
- End every session with retrospective summary.
- If execution blocks early, run partial closeout phases: `report-writer`, `history-logger`, `feedback-architect`.
- Memory update checkpoint: feedback-architect proposes updates, orchestrator checkpoints for engineer approval before applying.
