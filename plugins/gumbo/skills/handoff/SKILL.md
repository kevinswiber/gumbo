---
name: handoff
description: Generate a paste-ready resume prompt for continuing work in a fresh session when context grows large. Use when wrapping up a long session so the next one picks up cleanly with one well-defined next action.
---

# Handoff

Produce a **paste-ready prompt** that lets a fresh session resume this work. Use it for a deliberate clean break into a new session, as opposed to the harness's in-session compaction. If a hook-driven `context-handoff` skill is installed, it performs the same steps with project auto-detection; the contract below is what either must produce.

## Durable records first, then point at them

The prompt must be small and stable, so it carries pointers, not state:

1. **Flush in-flight state to disk.** Plan work: `.plan-state.json` (`current_task`, `last_session_notes`, `progress`, `commits`) and a finding for any decision or deviation this session. Research work: `.research-state.json` and the Expected Outputs table. Coordinator work: `HANDOFF.md` and the ledger. A decision not yet recorded gets recorded now (a finding, or `/adr-create`), not restated in the prompt.
2. **Write the handoff file** where the next session will look: an in-progress artifact gets `handoff-<topic>.md` in its directory; otherwise the project's `HANDOFF.md`. Keep it under about 300 lines, moving history to the ledger (AGENTS.local.md, Handoff records). This file is the durable copy; the prompt is its distilled pointer.
3. **Commit** the records to the gumbo repo.

## What the prompt contains

- **Where to start:** the working directory and the read-first order by authority (memory keys, the handoff file, the artifact files, related ADRs or research).
- **One next action:** a single concrete move, with the resume command (`/plan-resume`, `/research-resume`, a review loop), not a menu. The queue of later moves lives in the handoff file.
- **Active constraints:** read-only directories, commit scope, branch and naming conventions, anything that causes harm if forgotten.
- **What is decided:** pointers to the records that hold the detail, so the new session does not relitigate or redo.
- **In-flight gotchas:** a stop rule, a gated dependency, a known fragile seam.

Present it as one clearly delimited block the user can paste verbatim. Do not transcribe file contents into it, and do not write "pick up where I left off".
