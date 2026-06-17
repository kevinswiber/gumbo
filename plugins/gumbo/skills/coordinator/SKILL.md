---
name: coordinator
description: Operate or resume a long-lived cross-project coordinator role over gumbo plans, research, issues, and ADRs. Use when you are tracking and sequencing work across one or more repos rather than implementing it — creating plans/research, processing external reviews, recording landings, and keeping roadmaps true.
---

# Coordinator Skill

Run a durable **coordinator** role: you orchestrate planning, research, decisions, and landings across one or more projects, but you do **not** implement. Implementation happens in separate `plan-resume` sessions in the target repos. Your job is to keep the plan-of-record true, sequence the work, process reviews, and record what landed — in a way that **survives across many sessions and a fresh context**.

## When to use

- You are tracking/sequencing work across repos and want it to stay coherent over time.
- You are resuming a coordinator role someone (possibly you, last week) was running.
- You are *not* writing the production code yourself — you create the plans and records that others (or later sessions) execute.

## The durable artifacts that make the role resumable

A coordinator role is only as good as the records it leaves. Maintain, in the gumbo project directory:

- **`HANDOFF.md`** — the resume document. The role/charter, a "read first" authority order, the current state, the next-action queue, and the operating conventions. A fresh session reads this first and can pick up cold. Keep it **continuously** true, not just at session end.
- **`findings.md`** (or a decision/deviation ledger) — append-only, dated entries recording every decision, deviation, review, and landing. This is the audit trail. Convert relative dates to absolute. Read the last few entries to recover recent state.
- **`roadmap.md`** (when the work has milestones) — milestones with per-row status, dependency/sequencing notes, and named landing plans; the single place sequencing lives. Build and maintain it with **`roadmap-create`**.
- **The auto-memory** — a condensed timeline pointer, so the role's existence and cursor survive even without reading the full ledger.

**Resume in authority order:** HANDOFF → the last ~4 findings entries → roadmap → memory. Then act.

## Core loops

1. **Create** — turn requests into plans (`plan-create`), research (`research-create` / `research-resume`), decisions (`adr-create`), or issues. You set up the artifact; a separate session implements it.
2. **Process external reviews** — the owner pastes reviewer output. **Verify every load-bearing claim against source before applying it** (a reviewer can be wrong; a draft can be right). Prefer the **minimal** remedy. Record the review and its resolution in the ledger. Re-sweep for the same class of issue elsewhere — reviews usually surface a pattern, not a one-off.
3. **Record landings** — when work merges, run the landing ritual (below).
4. **Keep records true** — after every move, reconcile HANDOFF, findings, roadmap, and memory so the next session inherits an accurate picture.

## The landing ritual

When a plan's work merges:

- **Verify it actually landed** — check the PR/merge and the git log; don't take "done" on faith.
- **Mark the plan complete** — update its state file and status headers, then move it to `archive/` (`plan-archive`).
- **Reconcile the records** — update the roadmap row(s), append a dated findings entry, update any per-project roadmap, and update the memory cursor.
- **Commit the gumbo state** (see Git discipline). Parallel implementer sessions often leave uncommitted gumbo state (plan states, findings) — sweep it into your landing commit and say so.

## Delegation discipline (keep your own context lean)

You are an orchestrator; your context is the scarce resource. When you fan work out to agents:

- **Agents author to disk and return a terse summary.** Tell each agent the file *is* the deliverable and to reply with a few bullets, not the content. The artifact lands on disk; your context stays small.
- **Share one interface contract** across coupled parallel agents (see `adr-create` / `plan-create`) so their outputs don't drift; verify the seam after they return.
- **Agents never commit and never edit the source repos** — read-only; they propose, you record. (Editing source happens only in the target-repo implementation sessions.)
- When a create-skill spawns an authoring agent, set `planning_agent_id: null` in the artifact and **patch it afterward** from the returned agent id.
- For a tightly-coupled set of documents that must agree exactly, consider authoring directly instead of fanning out — cross-agent drift on a shared seam is the main risk.

## Decisions → records

A research synthesis or a design decision becomes a durable **ADR** (`adr-create`): draft in `adr-drafts/`, the owner **approves by status-line edit**, and it **lands in-repo via an implementation plan** (never by rewriting in place). Extend a landed decision with an appended `## Amendment` section, also landed via a plan. Name the landing plan in the ADR's status line, and state the **sequencing/gating** explicitly (what must land before what — a "two-step gate" where approval unblocks plan creation and *landing* unblocks the next phase is a common and useful shape).

## Git / gumbo discipline

- The gumbo directory is usually a symlink to a private store (e.g. `~/.gumbo/projects/<name>/`) that is its **own git repo**, separate from the code repos. Read the project config to find it.
- **Commit scoped to this project's subdirectory.** Conventional commits, lowercase. **No co-author line.** Push only when asked.
- **Never push (or commit to) a code repo** for a gumbo-only change. Keep operations scoped to whichever repo the request applies to.

## Handing off

Keep `HANDOFF.md` true as you go. When context runs low, use **`handoff`** to produce a paste-ready resume prompt for a fresh session — it flushes in-flight state to the durable records first, then points the new session at them (cwd + read-first order), names the single most important next action, and carries the active constraints. A clean handoff with one well-defined next move beats a long session running on fumes.
