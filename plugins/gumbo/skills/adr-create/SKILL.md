---
name: adr-create
description: Draft or amend a durable Architecture Decision Record for a design decision.
---

# ADR Create

Turn a design decision (often a research synthesis) into a reviewable **Architecture Decision Record**, or amend one that has landed. An ADR records what was decided, why, and what was rejected, so the rationale outlives the people who made it. Shared rules are in `.gumbo/AGENTS.local.md`.

## When

- A research plan reached a conclusion (`/research-resume`, state `synthesized`) that should be recorded as a decision rather than left in findings.
- A design decision is being made that future readers will need the rationale for.
- A landed decision needs a back-compatible extension or an as-built correction (amendment mode).

## Where

- **Landed ADRs** live in the code repo, `docs/adr/adr-NNNN-slug.md` or the repo's existing ADR location.
- **Drafts** live beside the work that produced them: `.gumbo/research/NNNN-topic/adr-drafts/` or `.gumbo/plans/NNNN-name/adr-drafts/`, named `<repo>-adr-NNNN-slug.md`. A draft names its target repo path and lands through an implementation plan (`/plan-create`). Rationale stays in gumbo; the decision lands in the repo.
- **Numbering:** one more than the highest `adr-NNNN` across the target repo's `docs/adr/` and all pending drafts.
- **Cross-repo decisions:** one draft per target repo, prefixed with the repo name, sharing one interface contract.

## Format

Match the target repo's existing ADRs. The conventional skeleton:

```markdown
# ADR-NNNN: Title

**Status:** DRAFT — pending owner approval; lands in-repo via <plan>
**Date:** YYYY-MM-DD
**See also:** [ADR-XXXX](./adr-XXXX-slug.md)

## Context
[The forces at play, grounded in source (`path:line`) and prior art.]

## Decision
[One `###` per distinct decision. Exact field names, signatures, vocabularies, shapes: a reader implements from this.]

## Consequences
### Accepted
### Rejected
[Alternatives and why not: half the value of an ADR.]

## Revisit Triggers
[Observable conditions under which to reopen this.]
```

Keep it as dense as the repo's landed ADRs, not longer. Because the text will land in a public repo, it must not depend on private artifacts: no plan numbers, task ids, research paths, or gumbo references in the body; cite the research by its public conclusions, not its path.

## Approval, amendment, sets

- **Approval is a status-line edit.** The owner changes the line to `**Status:** Accepted (owner-approved YYYY-MM-DD); pending in-repo landing via <plan>`. Nothing lands until an implementation plan lands it. Before recording approval, confirm the substrate the decision rests on has not moved since the draft was written.
- **Amendments.** Never rewrite a landed ADR. Append `## Amendment: <title>` at the end, name each decision the amendment extends or supersedes, say whether the original stands, keep the top-level status Accepted. Draft it in `adr-drafts/` first and land it via a plan.
- **Multi-ADR sets** get a cover memo beside the drafts (`<topic>-adr-cover.md`): what each draft decides, the open questions with a recommendation each, the landing plans and sequencing, and an approval checklist. The cover is the owner's single entry point. Coupled drafts share one interface-contract block; when they are authored in parallel, every agent gets it verbatim.
- **Revisions propagate.** A changed value echoes in sibling drafts, the cover's table, and See-also lines; sweep them all (AGENTS.local.md, single source then propagate).

## Process

1. Identify the source decision, the target repo, and the next free number.
2. Draft in `adr-drafts/` in the repo's ADR format, status DRAFT, naming the intended landing plan.
3. For a set, write the cover memo.
4. Present for review (`/adr-review`, or a Codex loop). Apply review findings minimally and record the review in the research or plan findings.
5. On owner approval, set the status line(s) and tick the cover.
6. Land via `/plan-create`: an implementation plan appends the ADR or amendment into the repo's `docs/adr/`, with the status line reduced to `**Status:** Accepted (YYYY-MM-DD)`; the `pending in-repo landing via <plan>` clause is draft metadata and does not land. This skill never edits the source repo; it commits the drafts to the gumbo repo.
