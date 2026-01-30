# Claude Code Instructions for Research

**IMPORTANT**: Do *not* commit research to the git repo!

When working on this project, follow these guidelines for creating and managing research.

## Creating Research

When starting a research investigation:

1. **Create a new numbered subdirectory** in `research/`:
   - Find the highest existing number across both `research/NNNN-*` and `research/archive/NNNN-*`
   - Ignore unnumbered legacy directories (e.g., `dagre-layout/`, `edge-routing-deep-dive/`)
   - Increment for your new research (e.g., `0001-edge-attachment`)
   - Use lowercase kebab-case for the topic name

2. **Save your research plan** to the new directory:
   - Research plan: `research/NNNN-topic-name/research-plan.md`
   - State file: `research/NNNN-topic-name/.research-state.json`
   - Findings files: `research/NNNN-topic-name/qN-descriptive-name.md`
   - Synthesis: `research/NNNN-topic-name/synthesis.md`

3. **Include a status header** at the top of the research plan:
   ```markdown
   ## Status: PLANNED
   ```

   Valid statuses:
   - `PLANNED` — Research questions defined, agents not yet spawned
   - `IN PROGRESS` — Investigation agents running
   - `SYNTHESIZED` — All questions answered and findings synthesized
   - `ARCHIVED` — Research complete and moved to archive

## State File (.research-state.json)

Each research plan has a `.research-state.json` file for tracking session state:

```json
{
  "status": "planned",
  "created_at": "2026-01-28T10:30:00Z",
  "updated_at": "2026-01-28T10:30:00Z",
  "planning_agent_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "agent_ids": [],
  "synthesis_agent_id": null,
  "last_session_notes": null
}
```

**Fields:**
- `status` — Research status: `"planned"`, `"in_progress"`, `"synthesized"`, or `"archived"`
- `created_at` — When the research plan was created (UTC ISO 8601)
- `updated_at` — Last time state was updated
- `planning_agent_id` — Agent ID from the planning session (can be resumed for context)
- `agent_ids` — Array of agent IDs from parallel investigation agents
- `synthesis_agent_id` — Agent ID that performed synthesis (null if done inline)
- `last_session_notes` — Notes from the last session about progress/next steps

**Additional fields for archived research:**
- `archived_at` — When the research was archived

## Research Plan Format

```markdown
# Research: Topic Name

## Status: PLANNED

---

## Goal

[What we're trying to learn and why]

## Context

[Current state, what prompted this research]

## Questions

### Q1: [Question title]

**Where:** [Sources to investigate]
**What:** [Specific information needed]
**How:** [Methodology]
**Why:** [Why this matters]

**Output file:** `q1-descriptive-name.md`

---

### Q2: [Question title]
...

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| [Name] | [Path/URL] | Q1, Q2 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-descriptive-name.md` | Q1: Title | Pending |
| `synthesis.md` | Combined findings | Pending |
```

## Findings File Format

Each investigation produces a findings file following the where/what/how/why framework:

```markdown
# Q1: [Question Title]

## Summary
[2-3 sentence answer]

## Where
[Sources consulted — files, repos, docs]

## What
[Detailed factual findings]

## How
[How the system/algorithm/feature works]

## Why
[Design rationale, tradeoffs, constraints]

## Key Takeaways
- [Takeaway 1]
- [Takeaway 2]

## Open Questions
- [Follow-up questions that emerged]
```

## Synthesis Format

After all questions are answered, findings are synthesized:

```markdown
# Research Synthesis: Topic Name

## Summary
[Executive summary]

## Key Findings
### [Finding 1]
[Cross-cutting finding from multiple questions]

## Recommendations
1. **[Recommendation]** — [Rationale]

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | [Key locations/sources] |
| **What** | [Core facts] |
| **How** | [Key mechanisms] |
| **Why** | [Design rationale] |

## Open Questions
- [Questions for potential deeper research]

## Next Steps
- [ ] [Follow-up actions]

## Source Files
| File | Question |
|------|----------|
| `q1-file.md` | Q1: Title |
```

## Parallel Execution

Research questions are investigated in parallel by independent subagents:
- Each agent gets one question and writes one findings file
- Agents run in the background using `run_in_background: true`
- Agent IDs are stored in `.research-state.json` for tracking
- Synthesis happens after all agents complete

## Hierarchical Research

When a research plan reveals subtopics needing deeper investigation:
- Create a subdirectory: `research/NNNN-topic/subtopic-name/`
- The subdirectory gets its own `research-plan.md` and `.research-state.json`
- The parent's synthesis should reference the child research

## Lifecycle

```
/research:create  ->  PLANNED  (research plan designed, questions defined)
/research:resume  ->  IN PROGRESS  (parallel agents spawned)
/research:resume  ->  SYNTHESIZED  (findings combined into synthesis.md)
/research:archive ->  ARCHIVED  (moved to research/archive/)
```

## Cross-References

- Implementation plans in `plans/` reference research via relative paths: `../../research/NNNN-topic/doc.md`
- Research plans should reference relevant existing research and plans
- Synthesis documents should suggest next steps including potential implementation plans

## Example Directory Structure

```
research/
├── archive/                          # Archived research
│   └── 0001-edge-routing/
│       ├── research-plan.md
│       ├── .research-state.json
│       ├── q1-mermaid-behavior.md
│       ├── q2-dagre-routing.md
│       ├── q3-ascii-constraints.md
│       └── synthesis.md
├── 0002-layout-algorithm/            # Active research
│   ├── research-plan.md
│   ├── .research-state.json
│   ├── q1-sugiyama-theory.md
│   ├── q2-rust-libraries.md
│   └── deeper-dive/                  # Hierarchical sub-research
│       ├── research-plan.md
│       ├── .research-state.json
│       └── q1-network-simplex.md
├── dagre-layout/                     # Legacy (unnumbered)
├── edge-routing-deep-dive/           # Legacy (unnumbered)
├── CLAUDE.md
└── README.md
```
