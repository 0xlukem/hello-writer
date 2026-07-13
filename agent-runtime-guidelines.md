# Agent Runtime Guidelines - Content Engine

This file defines how agents operate together in v1.
It is mandatory for orchestrator and all workflow agents.

## 1) Control Model
- `orchestrator` is the only runtime controller.
- All specialist agents run only through orchestrator delegation.
- No phase may bypass orchestrator checkpoints.

## 2) Execution Model
- Default mode is step-by-step sequential phase execution.
- Orchestrator decisions are based on confidence thresholds, not engineer approval at every step.
- Gate failures follow the workflow retry loop.
- Every approval-required checkpoint must produce a transcript artifact under `.opencode/testing/checkpoint-transcripts/`.

## 3) Mandatory vs Skippable Phases
- Default expectation: run the full workflow phase list.
- A phase may be skipped only when not applicable to the approved task scope.
- Skips require explicit orchestrator checkpoint approval.

## 4) Confidence Score System

### 4.1 Research Confidence
- `research_confidence`: `high` | `medium` | `low`
- Rubric:
  - `high`: minimum 4-5 verified sources from different domains, conflicting claims resolved, stats backed by primary sources
  - `medium`: 2-3 solid sources but one or more gaps need confirmation
  - `low`: fewer than 2 sources, partial data, inferred angles, unresolved conflicting claims
- Research depth requirement:
  - Must consult at least 2 different source types (GitHub, official docs, articles, HN/Reddit, podcasts)
  - Must validate company/tool claims by checking official sources
  - Must flag any single-source claims immediately
- Thresholds:
  - `high` -> proceed normally
  - `medium` -> checkpoint: "Limited data - provide more sources, change angle, or proceed with caveats?"
  - `low` -> BLOCK: "Insufficient research. Need more sources or new topic"

### 4.2 SEO Opportunity Confidence
- `seo_opportunity_confidence`: `high` | `medium` | `low`
- Rubric:
  - `high`: clear keyword gap, low competition, high search intent match
  - `medium`: viable opportunity but competitive or niche
  - `low`: saturated niche or unclear search intent

### 4.3 Content Quality Score
- `content_quality_score`: `0-100`
- Components:
  - Grammar & spelling: 25 points
  - Flow & readability: 25 points
  - Voice consistency: 25 points
  - Fact-check flags: 25 points
- Thresholds:
  - `>= 85` -> PASS, proceed
  - `70-84` -> LOOP to writer (max 2 loops for blog, max 1 for short-form)
  - `< 70` -> BLOCK + checkpoint: "Rewrite from scratch or manual approve?"

### 4.4 Session Confidence
- `session_confidence`: `high` | `medium` | `low`
- Rubric:
  - `high`: all gates passed, quality >= 85, no major issues
  - `medium`: gates passed but with loops, quality 70-84, minor issues
  - `low`: blocked phases, quality < 70, major issues unresolved
- Thresholds:
  - `high` -> update memory only
  - `medium` -> update memory + improvement alert
  - `low` -> checkpoint with major change recommendations

## 5) Tag Model
Use tags in skip decisions and matrix rows:
- `NO_RESEARCH_NEEDED`: `researcher` auto-skip when user provides full brief with sources.
- `NO_SEO_NEEDED`: `seo-expert` auto-skip when user provides explicit structure.
- `NO_SHORTFORM`: `repurposer` and platform writers auto-skip when only blog is requested.
- `BLOG_ONLY`: all short-form phases auto-skip.
- `NO_IMAGES`: `image-creator` auto-skip when engineer declines images or only text content is requested.

Voice guidance from the user never skips `digital-twin`; it is passed into `digital-twin` so the agent can normalize it into platform-specific Voice Briefs before writers run.

Risk scale is always `none|low|medium|high`.
`high` risk skips are forbidden.

## 6) Skip Contract (Required)
When skipping a phase, orchestrator must record:

```text
PHASE SKIP JUSTIFICATION
- phase: <agent/phase name>
- reason: <why not applicable>
- scope_impact: <what is excluded>
- risk_assessment: <none|low|medium|high + short note>
- safety_guard: <why remaining phases still validate outcome>
- checkpoint_id: <required>
- skip_tag: <NO_RESEARCH_NEEDED|NO_SEO_NEEDED|NO_SHORTFORM|BLOG_ONLY|NO_IMAGES>
- engineer_approval: <required>
- transcript_path: <required path under .opencode/testing/checkpoint-transcripts/>
```

## 7) Checkpoint Transcript Contract (Required)
Every approval-required checkpoint must be persisted to a transcript file with:

```text
CHECKPOINT TRANSCRIPT
- checkpoint_id: <required>
- phase: <required>
- decision_needed: <required>
- options_presented: <required>
- recommendation: <required>
- engineer_decision: <required>
- known_good_state_verification: <required>
- known_good_reference: <required>
  - branch_or_ref: <required>
  - commit_or_revision: <required>
  - build_evidence: <required>
- approval_timestamp: <required>
- operator: <required>
- commands_executed_after_approval: <required>
```

## 8) Handoff Contract
Every delegated phase must return the standard phase output block.
When skipped, the phase output must still be represented with:
- `phase_status: SKIPPED`
- `skip_justification` block (same fields as skip contract).

## 9) Phase Applicability Matrix
Legend:
- `M` mandatory, never skippable
- `C` conditional, skippable only for defined tag condition
- `S` skippable with strict criteria and low/none risk only

| Phase | Mode | Run When | Skip When | Allowed Tags | Notes |
| --- | --- | --- | --- | --- | --- |
| orchestrator | M | Always | Never | none | Runtime owner |
| researcher | C | New topic or no sources provided | User provides full brief + sources | `NO_RESEARCH_NEEDED` | Auto-skip, full skip contract required |
| seo-expert | C | Blog requested | User provides explicit structure | `NO_SEO_NEEDED` | Auto-skip, full skip contract required |
| digital-twin | M | Always before writers | Never | none | Voice brief generator |
| blog-writer | M | Blog requested | Never | none | Core asset |
| editor | M | Always after writer | Never | none | Quality gate |
| image-creator | C | Images approved by engineer | Engineer declines or `NO_IMAGES` | `NO_IMAGES`, `BLOG_ONLY` | Requires editor score >= 85; two-step approval |
| repurposer | C | Short-form requested | Only blog requested | `NO_SHORTFORM`, `BLOG_ONLY` | Auto-skip, full skip contract required |
| linkedin-writer | C | LinkedIn requested | Not requested | `BLOG_ONLY` | Auto-skip |
| x-thread-writer | C | X thread requested | Not requested | `BLOG_ONLY` | Auto-skip |
| reel-script-writer | C | Reel requested | Not requested | `BLOG_ONLY` | Auto-skip |
| editor-light | C | Short-form requested | Not requested | `BLOG_ONLY` | Auto-skip |
| feedback-architect | M | Always at session end | Never | none | Learning loop |
| report-writer | M | Always at session end | Never | none | Closeout artifact |
| history-logger | M | Always at session end | Never | none | Audit trail |

## 10) Retry Loop Rules
- Blog Editor: max 2 retry loops (initial + 2 rewrites)
- Short-form Editor: max 1 retry loop
- If retry cap reached and quality still < threshold -> BLOCK + checkpoint

## 11) Blocked Session Closeout Policy
If execution blocks early, orchestrator must still run partial closeout with:
- `report-writer`
- `history-logger`
- `feedback-architect`

## 12) End-of-Session Retrospective (Mandatory)
At the end of every session, feedback-architect must include:

```text
SESSION RETROSPECTIVE
- what_we_did:
  - <summary of phases run>
- what_we_learned:
  - <lesson>
- what_went_ok:
  - <item>
- what_went_wrong:
  - <item>
- how_do_we_fix_it:
  - <fix>
- what_we_could_do_better_next_time:
  - <improvement>
- session_confidence: <high|medium|low>
```

## 13) Learning and Memory Routing
- `feedback-architect` produces retrospective learnings and proposes memory updates.
- `history-logger` stores factual retrospective summaries in history logs.
- Agent memory files under `.opencode/agents/memory/` are updated with reusable, non-duplicate patterns.
- **Memory updates require engineer approval**: feedback-architect PROPOSES but NEVER writes to memory files directly. Orchestrator must checkpoint with engineer before applying any proposed memory changes.
- **History log exception**: history-logger may append factual audit entries to `.opencode/agents/memory/history-logger.memory.md` without a memory-update approval checkpoint. It must not write editorial lessons or reusable preferences outside that audit log entry.

## 14) Memory Update Workflow

### 14.1 Proposal Phase
1. `feedback-architect` analyzes session outputs.
2. Identifies patterns that should be persisted to memory.
3. Proposes specific updates for each affected memory file.
4. Outputs proposals in `proposed_memory_updates` field.

### 14.2 Approval Phase
1. Orchestrator presents proposals to engineer.
2. Engineer reviews and approves/rejects each proposal.
3. Only approved updates are written to `.opencode/agents/memory/*.md`, except factual history-logger audit appends described above.

### 14.3 Application Phase
1. Orchestrator applies approved updates.
2. Rules for updates:
   - Non-duplicate entries only
   - Date-tagged
   - Keep files under size cap (200 lines for most, 1000 for history)
   - Archive old entries if cap exceeded

## 15) Safety and Governance
- Do not skip mandatory gates (editor, feedback-architect, history-logger).
- **Do not auto-apply permanent rule changes.**
- **Rule updates and memory file updates remain apply-only-after-engineer-approval.**
- The feedback-architect may PROPOSE memory updates but must NEVER write to `.opencode/agents/memory/*.md` directly.
- Orchestrator must checkpoint with engineer before applying any proposed memory changes.
- History-logger may append factual audit entries to its own memory file without approval, but may not mutate other memory files.
- All content must be saved to `output/YYYY-MM-DD_topic/`.
  - `final/` - delivery-ready assets (`blog.md`, `linkedin-post.md`, `x-thread.md`, `reel-script.md`)
  - `artifacts/` - supporting documents (`research-brief.md`, `seo-analysis.md`, `voice-brief-*.md`, `repurposer-output.md`, `editor-output.md`, `feedback-architect.md`)
  - `images/` - AI-generated blog images (`<topic-slug>-photo-1.png`, etc.)
  - `_meta.md` - session report at the root of the topic folder
