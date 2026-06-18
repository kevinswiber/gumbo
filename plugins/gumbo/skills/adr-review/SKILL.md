---
name: adr-review
description: Review an Architecture Decision Record (or coupled ADR set + cover) for grounding, decisiveness, completeness, and internal consistency before it is approved or landed — and to catch the drift that iteration introduces across coupled drafts and the cover. Reports findings; does not auto-fix unless asked.
---

# ADR Review Skill

Review an ADR the way a careful owner would before approving it: confirm the decision is grounded in current source, specific enough to implement from, honest about what it rejected, and internally consistent — across a coupled set and its cover. This is the **reactive net** for the drift that creeps in as an ADR is iterated (the proactive side is the anti-drift / propagate-on-revise rule in `adr-create`).

## When to use

- Before an owner approves an ADR (the status-line approval is the gate this review feeds).
- After an ADR has been **iterated** — a review applied, a decision sharpened, a shared seam changed — the moment most likely to have left a sibling draft or the cover contradicting the anchor.
- Before landing, as the **drift check**: confirm nothing decided since the draft was written has moved the substrate it depends on.
- When asked to "review" or "sanity-check" an ADR or ADR set.

## What to check

Verify each load-bearing claim against the actual ADR and current source before reporting it — a reviewer can be wrong and an ADR can be right.

1. **Internal consistency (the drift net — the highest-value pass).**
   - **Coupled ADRs agree on their shared seam.** A vocabulary term, wire shape, field name, or predicate that both ADRs must honor reads **identically** in each. The interface contract is one contract, stated the same everywhere.
   - **The cover matches its drafts.** The resolved-questions table, the "what each decides" list, and the cross-reference lines in `<topic>-adr-cover.md` agree with the drafts they describe. A cover that contradicts its drafts is the classic ADR-set defect.
   - **No stale references.** Grep the whole ADR — and every sibling draft plus the cover — for any value changed during iteration (a renamed field, a superseded shape, an old number). A value changed in the anchor echoes in dependents' interface-contract references, the cover's table, and the `See also` lines; reconcile every occurrence.
   - **Status lines and cross-refs are correct.** Each status line follows the lifecycle (`DRAFT — pending owner approval` / `Accepted (owner-approved <date>); pending … landing via <plan>`) and names the right landing plan; the cover's approval checklist matches the drafts' statuses; every `ADR-XXXX` / `See also` link resolves to an ADR that exists.
2. **Grounding & current substrate.** Context claims are cited to source — `path:line` for codebase facts, precise citations for prior art. Crucially, the load-bearing substrate the decision rests on (a format, interface, or contract) is **still true now** — verify it against current source, not the source as it was when the draft was written. A decision approved against a moved foundation is a latent bug.
3. **Decision quality & completeness.** The Decision section is **decisive and implementable** — exact field names, signatures, vocabularies, shapes — not a vague survey a reader can't build from. Consequences include **Rejected** alternatives with their reasons (this is half an ADR's value); Revisit Triggers are concrete conditions, not platitudes.
4. **Faithfulness.** The ADR honors the decision it records (the research synthesis or stated design choice) — it does not invent, overstate, or quietly resolve a question the source left open. It honors, not contradicts, any ADR it cites.

## Amendments — review against append-only discipline

If the target is an **amendment** to a landed ADR: confirm it is *appended* as a `## Amendment: …` section and **the original text is untouched**, the top-level Status remains `Accepted`, and the amendment states whether the original decision still stands. A diff that rewrites the landed decision's original prose is itself a blocking finding — corrections to a landed ADR go through an amendment, never an edit.

## How

- Read the ADR top-to-bottom; for a set, read the cover and **every** sibling draft.
- Build a small map of the shared interface contract (the terms/shapes/predicates the coupled ADRs share) and check each reads identically everywhere it appears, including the cover's table.
- For each value changed in iteration, **grep all drafts + the cover** for the old form.
- Verify each load-bearing substrate claim against **current** source; check ADR numbering doesn't collide and every cross-reference link resolves.
- Ground every finding in a specific `file:line` and state the **minimal** remedy.

## Output

Report findings grouped by severity, each with location and a minimal fix — do **not** rewrite the ADR unless explicitly asked to apply fixes:

```
**[Blocking]** <seam disagreement / unsupported or moved-substrate claim> — `relay-adr-0004-…md:NN` vs `adr-cover.md:NN`. <why it matters> Fix: <minimal reconcile>.
**[Should-fix]** …
**[Nit]** …
```

Close with a one-line verdict (approve / approve-with-fixes / needs-changes) — this feeds the owner's status-line approval. If asked to **apply** the fixes, make the minimal change and re-sweep the whole ADR, every sibling draft, and the cover (per `adr-create`'s anti-drift rule) so the fix propagates everywhere the value appears and doesn't introduce new drift. Never rewrite a **landed** ADR to apply a fix — route the correction through an amendment.
