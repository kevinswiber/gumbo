---
name: roadmap-create
description: Create and maintain a roadmap that sequences milestones and the plans, research, and decisions that fulfill them. Use when work spans many artifacts over time and needs one living place that shows the sequence, status, dependencies, and risks.
---

# Roadmap Skill

A **roadmap** is the single living place that sequences work across many artifacts and over time. It is *not* a plan: a plan implements one feature; a roadmap arranges many plans, research efforts, and decisions into milestones, tracks their status, and records what depends on what. Build one when the work is large enough that "what's next and why" is no longer obvious from the individual plans.

## Where it lives

- A single-project roadmap: `.gumbo/roadmap.md`, or `.gumbo/analysis/<name>-roadmap/roadmap.md` when it warrants its own directory (with supporting files like a current-state snapshot, a risks list, a findings ledger).
- A **cross-project** roadmap (sequencing work across several repos): a shared roadmap directory, with per-project roadmaps deferring to it for cross-project sequencing.

## Structure

A roadmap has four parts:

1. **Milestones** — coherent deliverables in order (`M0, M1, …`, or named phases). Each milestone has an **exit criterion**: the observable thing that is true when it's done. Milestones are the columns of the sequence; rows live under them.

2. **Rows** — each row is one unit of work toward a milestone. A row carries: a short **id + title**, the **owning repo/component**, a one-line **description**, a **status**, and a **link to the artifact that fulfills it** (a plan, a research dir, an ADR). The roadmap *sequences*; the linked artifacts *execute*. A common table shape:

   ```markdown
   | # | Item | Owner | What / why | Status | Artifact |
   |---|------|-------|------------|--------|----------|
   | M1.2 | Public admission API | boardwalk | Expose caller identity to embedded actors | ✅ landed (PR #36) | plan 0010 |
   | M2.3 | Event-sync plane | relay | Cursor/gap/replay over the tunnel | ⬜ not started | (plan TBD) |
   ```

3. **Dependencies & sequencing** — what must land before what; the **named landing plans**; explicit **gates** (e.g. a two-step gate where approval unblocks plan creation and *landing* unblocks the next phase). This is the part that prevents work from being started out of order.

4. **Risks** — the things that could derail the sequence, each with a mitigation or an owner. Surfacing them on the roadmap keeps them from being rediscovered late.

## Keep it true (a roadmap is a living document)

- Update row status as work lands — this is part of the landing ritual (see the `coordinator` skill). A roadmap that lags reality is worse than none, because it's trusted.
- Convert relative dates to absolute.
- When a row's plan/research/ADR is created, link it; when it lands, mark it and note the merge.
- Keep the *sequencing rationale* on the roadmap and the *implementation detail* in the linked artifacts — don't duplicate.
- **Propagate every change across the roadmap (the anti-drift rule, same as `plan-resume` / `research-resume`).** When a milestone, a row's status, or a dependency changes, a roadmap echoes it in several places — the milestone table, the dependency/sequencing section, the risks, any per-project roadmap that defers to this one. Sweep them all and reconcile before moving on; a roadmap that contradicts itself misroutes the work it exists to sequence.

## Relationship to other skills

- Rows point at **`plan-create`** (implementation), **`research-create`** (investigation), and **`adr-create`** (decisions). The roadmap names *what* and *in what order*; those skills produce the *how*.
- The **`coordinator`** role maintains the roadmap as one of its durable artifacts and keeps it true across sessions.

## Process

1. Identify the milestones and their exit criteria.
2. Lay out the rows under each milestone, linking any existing plans/research/ADRs and marking the rest as TBD.
3. State the dependencies, named landing plans, gates, and risks.
4. Thereafter, **maintain** it: update status on every landing, link artifacts as they're created, and keep the sequencing rationale current.
