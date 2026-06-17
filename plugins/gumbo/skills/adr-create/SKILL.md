---
name: adr-create
description: Draft or amend an Architecture Decision Record (ADR) from a research synthesis or a design decision. Use when a decision needs to become a durable, reviewable record — and when extending or correcting a decision that has already landed.
---

# ADR Skill

Turn a design decision (often a research synthesis) into a durable, reviewable **Architecture Decision Record**, or **amend** one that has already landed. An ADR captures *what was decided, why, and what was rejected* so the rationale survives the people who made it.

## When to use

- A research plan reached a conclusion (`research-resume` → `synthesized`) that should be recorded as a decision, not left buried in findings.
- A design decision is being made that future readers will need the rationale for.
- A landed decision needs a back-compatible extension or an as-built correction (use the **Amendment** mode — never rewrite a landed ADR).

## Where ADRs live, and the draft → land flow

- **In-repo home:** the code repo's `docs/adr/adr-NNNN-slug.md` (or the project's existing ADR location). This is where an ADR *lands*.
- **Drafts** (the common case when the ADR comes out of research) live in the research dir's `adr-drafts/` subdirectory: `.gumbo/research/NNNN-topic/adr-drafts/<repo>-adr-NNNN-slug.md`. A draft names its **target repo path** and **lands in-repo via an implementation plan** (`plan-create`). Keep the rationale in gumbo; land the decision in the repo.
- **Numbering:** the next free ADR number is the highest existing `adr-NNNN` across the target repo's `docs/adr/` *and* any pending drafts. Check both.
- **Cross-repo decisions:** when one decision spans repos, write one draft per target repo (prefix the filename with the repo, e.g. `relay-adr-0004-…`), and keep their shared interface identical (see "Parallel authoring").

## Format

Match the target repo's existing ADRs if it has them. The conventional skeleton:

```markdown
# ADR-NNNN: Title

**Status:** DRAFT — pending owner approval (owner approves by status-line edit); lands in-repo via <plan>
**Date:** YYYY-MM-DD
**See also:** [ADR-XXXX](./adr-XXXX-slug.md), other related decisions

## Context
[The forces at play — what's true today, what problem this solves, the constraints. Ground claims in
source: cite files/symbols (`path:line`) and prior art precisely.]

## Decision
[What is decided. Use `###` subsections for each distinct decision. Be specific and decisive — name
exact field names, signatures, vocabularies, shapes. A reader implements from this.]

## Consequences

### Accepted
[What this buys, and what costs are accepted.]

### Rejected
[Alternatives considered and why they were not chosen — this is half the value of an ADR.]

## Revisit Triggers
[The concrete conditions under which this decision should be reopened.]
```

Keep it tight but complete — match the density of the repo's landed ADRs, not longer.

## Approval — by status-line edit

The owner approves an ADR by **editing its Status line**, not by a separate ceremony. Draft status lines read `DRAFT — pending owner approval` or `Proposed`; an approved ADR reads:

```
**Status:** Accepted (owner-approved YYYY-MM-DD); pending in-repo landing via <named plan>
```

When the owner approves, set the status line(s) and, for a multi-ADR set, check the cover's approval checklist. Do not land (move into the repo) until an implementation plan does it.

## Amendment mode — extending a landed ADR

A landed ADR is the decision of record; **never rewrite its original text**. To extend or correct it:

- Append a new `## Amendment: <short title>` section to the **end** of the landed ADR. State whether the original decision stands (it usually does — an amendment is a landing-record correction or a back-compatible extension, not a re-decision) and keep the top-level **Status: Accepted**.
- The amendment lands in-repo via an implementation plan, the same way the ADR did.
- Draft the amendment in `adr-drafts/` first (e.g. `<repo>-adr-NNNN-amendment-slug.md`) so it can be reviewed and approved before landing.

This keeps the decision history append-only and auditable, mirroring how the codebase itself is treated.

## Multi-ADR sets — a cover memo

When a decision produces more than one ADR (e.g. a shoreline ADR + a relay ADR, or an anchor amendment plus dependents), write a short **cover memo** beside the drafts (`<topic>-adr-cover.md`): the list of drafts and what each decides, the open design questions resolved with a recommendation each, the named landing plan(s) and sequencing, and an **approval checklist** the owner can tick. The cover is the owner's single review entry point.

## Parallel authoring — share one interface contract

Coupled ADRs (or a cross-repo pair) must agree on a shared seam — a vocabulary, a wire shape, a predicate. When fanning out parallel authoring agents, give **every** agent one identical **interface-contract block** verbatim (the shared verdicts, shapes, and constraints both ADRs must honor). Parallel agents cannot see each other's output; the contract is what keeps them aligned. After they return, verify the seam held across both drafts and reconcile any drift before presenting.

## Revising a draft — propagate the change

When you revise an ADR draft (a review applied, a decision sharpened), apply the **anti-drift rule** (same as `plan-resume` / `research-resume`): a changed value rarely lives in one place. Sweep the **whole** ADR — and, for a coupled set, **every** sibling draft plus the cover — for the old form and reconcile all of them before moving on. A value changed in the anchor ADR echoes in the dependents' interface-contract references, the cover's resolved-questions table, and the cross-reference lines; a cover that contradicts its drafts, or two coupled ADRs that disagree on a shared seam, is the classic ADR-set defect.

## Before approval — drift check

Before recording approval, confirm nothing decided *since* the draft was written has changed its substrate (a format, an interface, a contract the ADR depends on). Verify load-bearing claims against current source. A decision approved against a moved foundation is a latent bug.

## Process

1. Identify the source decision (a research synthesis, or a stated design choice) and the target repo + next free ADR number.
2. Draft the ADR in `adr-drafts/` (or directly in `docs/adr/` if landing immediately), in the repo's ADR format, with a DRAFT status line naming the intended landing plan.
3. For a multi-ADR set, write the cover memo. For coupled/parallel authoring, share one interface contract.
4. Present for review. Apply review minimally; record the review and resolution in the research/findings ledger.
5. On owner approval, set the status line(s) to `Accepted (owner-approved <date>)` and tick the cover.
6. Land via `plan-create` — an implementation plan appends the ADR (or its `## Amendment`) into the repo's `docs/adr/`, with the ADR's status line naming that plan.
7. Do **not** commit source-repo changes here — ADRs land through their implementation plan, not from this skill. (The gumbo-side drafts are committed per the project's gumbo git discipline; see `coordinator`.)
