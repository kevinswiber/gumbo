---
name: adr-review
description: Review a draft ADR or coupled ADR set for grounding, consistency, and readiness for owner approval.
---

# ADR Review

Review an ADR, or a coupled set with its cover memo, as the owner who will approve it by editing its status line and then implement from it. Read every draft and the cover, the ADRs it cites, and the current source the decision rests on. A reviewer can be wrong and the ADR can be right: verify before reporting.

## Checks

1. **Substrate is current.** The formats, interfaces, and contracts the Context section relies on are true at the current head, not as of when the draft was written. Code claims cite `path:line`; prior art is cited precisely.
2. **Decision is implementable.** Exact field names, signatures, vocabularies, shapes; one decision per `###`. A reader builds from it without guessing. Consequences name what is accepted and what was rejected and why; revisit triggers are observable conditions.
3. **Set consistency.** Coupled ADRs state their shared seam identically. The cover's list, resolved-questions table, and approval checklist match the drafts. Every `ADR-XXXX` and See-also link resolves, the status line names a real landing plan, and no number collides.
4. **Faithfulness.** The ADR records the decision its source (a synthesis or a stated choice) made, without inventing, overstating, or closing a question the source left open, and it does not contradict an ADR it cites.
5. **Amendments.** An amendment is appended; the original text is unchanged; it names each decision it extends or supersedes and says whether the original stands.
6. **Public surface.** Text that will land in a public repo does not depend on private artifacts: no plan numbers, task ids, research paths, or gumbo references.

## Output

One finding per issue, grounded in `file:line` (two locations for a seam or cover mismatch), with the minimal remedy. Severity: `blocking` (would be implemented wrong or approved against a moved foundation), `should-fix`, `nit`.

Verdict: `approved` when no blocking or should-fix findings remain; `revise` when some do; `blocked` only when the review cannot be completed or a finding needs an owner decision.

Do not rewrite the ADR. If asked to apply fixes, make the minimal change and propagate it across every sibling draft and the cover. Never edit a landed ADR's original text; route corrections through an amendment.
