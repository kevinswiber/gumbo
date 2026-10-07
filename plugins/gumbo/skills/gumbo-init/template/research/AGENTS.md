# Research

Research investigations live here, one directory per topic. Shared rules are in the project's `AGENTS.local.md`; the skills are `/research-create`, `/research-resume`, `/research-review`, `/research-archive`, `/research-cancel`. This file records the formats those skills read and write.

## Layout

```
research/
├── NNNN-topic-name/
│   ├── research-plan.md
│   ├── .research-state.json
│   ├── q1-descriptive-name.md     # one findings file per question
│   ├── q2-descriptive-name.md
│   ├── synthesis.md
│   ├── shared-contract.md         # optional; decided constraints every investigator receives
│   ├── adr-drafts/                # optional; decisions produced by this research
│   └── subtopic-name/             # optional deeper research, with its own plan and state
└── archive/
```

Numbers increase across active research and the archive; unnumbered directories are legacy and are ignored when numbering. Names are lowercase kebab-case.

## Lifecycle

`PLANNED` (`/research-create`) → `IN PROGRESS` → `SYNTHESIZED` (`/research-resume`) → `ARCHIVED` (`/research-archive`), or `CANCELLED`. The plan's `## Status:` header and the state file's `status` (`planned`, `in_progress`, `synthesized`, `archived`, `cancelled`) always agree.

## research-plan.md

```markdown
# Research: Topic Name

## Status: PLANNED

## Goal
## Context

## Questions

### Q1: Title
**Where:** sources
**What:** the facts to extract
**How:** read, run, compare
**Why:** what it decides
**Depends on:** (optional) Q2, Q3
**Output file:** `q1-descriptive-name.md`

## Shared contract
(optional) decided values, vocabulary, and seams every investigator receives verbatim

## Sources

| Source | Location | Used by |
|--------|----------|---------|

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-descriptive-name.md` | Q1: Title | Pending |
| `synthesis.md` | Combined findings | Pending |
```

`/research-resume` reads the status header and the Expected Outputs table.

## Findings file (qN-*.md)

Summary (the answer in a few sentences); Where (sources consulted); What (the facts, cited to `file:line` or a precise reference); How (how it works); Why (rationale and tradeoffs); Key Takeaways; Open Questions. Keep each section proportionate to what the question needs; a short Why is fine. Headline numbers show the data they come from.

## synthesis.md

Summary; Key Findings (cross-cutting, each traceable to question files); Decisions (owner decisions made during the research, dated, and the questions still open for the owner); Recommendations (one per decision, with rationale); Next Steps (what a plan or ADR should do); Source Files (table of file and question).

## .research-state.json

```json
{
  "status": "planned",
  "created_at": "2026-01-28T10:30:00Z",
  "updated_at": "2026-01-28T10:30:00Z",
  "last_session_notes": null
}
```

Archived research adds `archived_at`; cancelled research adds `cancelled_at`, `cancellation_reason`, `superseded_by`. Extra keys are allowed. `planning_agent_id`, `agent_ids`, and `synthesis_agent_id` are legacy optional keys; omit them or write null.

## Cross-references

Plans link research by relative path (`../../research/NNNN-topic/synthesis.md`). When research is archived, the path changes to `../../research/archive/NNNN-topic/`; `/research-archive` repoints links in the project.
