---
name: handoff
description: Generate a paste-ready resume prompt for continuing work in a fresh session when context grows large. Use when wrapping up a long session so the next one picks up cleanly with one well-defined next action.
---

# Handoff Skill

Produce a **paste-ready prompt** that lets a fresh session resume this work cleanly. Use it when context is running low and you want a deliberate clean break — not the harness's automatic in-session compaction (which preserves continuity in the *same* session), but a curated entry point for a *new* one.

## The core principle: durable records first, then point at them

A handoff prompt should be **small and stable**, so it must not carry the state — the durable files do. Before writing the prompt:

1. **Flush all in-flight state to disk.** Update the project's resume document (`HANDOFF.md`), the decision/deviation ledger (`findings.md`), and any plan/research state files so they reflect reality *now*. Record decisions made this session, mark what landed, note what's mid-flight.
2. **Then write a prompt that points at those files** rather than restating their contents. A paraphrase in the prompt goes stale the moment the files move on; a pointer ("read `HANDOFF.md`, then the last 4 findings entries") always resolves to the truth.

If there is no durable record to point at, create one first — a handoff prompt over un-recorded state just moves the fragility into the prompt.

## What a good handoff prompt contains

- **Where to start** — the working directory, and the **read-first order** (which files, in what order of authority). The new session orients from records, not from the prompt.
- **The single most important next action** — *one* concrete move, not a menu. "Create plan 0068 (it lands X)" beats "continue the M2 work."
- **Active constraints** — read-only directories, commit scope, naming/branch conventions, anything that would cause harm if forgotten.
- **What's already decided / done** — so the new session does not redo work or relitigate settled decisions. Reference the records that hold the detail.
- **In-flight gotchas** — a STOP rule, a gated dependency ("blocked on X's approval"), a known-fragile seam.

## What to avoid

- **Dumping raw state into the prompt.** Point at files; don't transcribe them.
- **A vague continuation** ("pick up where I left off"). Name the next action.
- **Re-deriving decisions in the prompt.** If a decision isn't yet recorded, record it (e.g. via `adr-create` or a findings entry), then reference it.
- **A long menu of options.** One clear next move; the queue of later moves lives in the resume document, not the prompt.

## Process

1. Flush in-flight state to the durable records (resume doc, ledger, state files).
2. Draft the prompt with the five elements above — favor pointers over restated content.
3. Present it as a clearly delimited, paste-ready block the user can drop into a new session verbatim.

## Relationship to other skills

- The **`coordinator`** role keeps its resume document (`HANDOFF.md`) continuously true; this skill turns that document plus the live state into the actual resume *prompt*.
- An implementer mid-plan can hand off too: flush `.plan-state.json` `last_session_notes`, then point the prompt at the plan and the current task.
