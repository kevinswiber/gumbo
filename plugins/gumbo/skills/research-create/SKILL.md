---
name: research-create
description: Create a question-based research plan for an investigation that will inform a decision or implementation plan.
allowed-tools: Bash(git log:*), Bash(git diff:*)
---

# Research Create

Design a research plan: the questions whose answers will settle a decision or ground an implementation plan. Shared rules are in `.gumbo/AGENTS.local.md`; file formats in `.gumbo/research/AGENTS.md`.

## 1. Decide whether research is the right tool

Research pays when the answer needs several sources read carefully and will be reused. When the open question is one observable fact about a system you can run, a probe (a spike branch, one experiment) is cheaper; say so and offer it instead. Check `.gumbo/research/` and its `archive/` for prior work on the topic first and link what applies.

## 2. Ground the plan

Read enough of the codebase and the prior artifacts to know what is already known and where the sources are. Delegate a bounded exploration only when it is authorized and the topic is large.

## 3. Design the questions

Each question is independent where possible, answerable from named sources, and tied to the decision it informs. For each give a title, **Where** (sources), **What** (the facts to extract), **How** (read, run, compare), **Why** (what it decides), and the output file `qN-slug.md`. Keep the four lines proportionate; a one-line Why is fine. Mark questions that depend on other questions' outputs so `/research-resume` sequences them. When questions share decided constraints or vocabulary, write a shared-contract block once in the plan (or in `shared-contract.md`) that every investigator receives verbatim.

## 4. Write the directory

`.gumbo/research/NNNN-topic/`, next number across active research and `archive/`, ignoring unnumbered legacy directories:

- `research-plan.md`: `## Status: PLANNED`, Goal, Context, Questions, a Sources table, and an Expected Outputs table with one row per `qN` file plus `synthesis.md`, status Pending. `/research-resume` reads the status header and the Expected Outputs table; keep those exact.
- `.research-state.json`:
  ```json
  {"status": "planned", "created_at": "<UTC>", "updated_at": "<UTC>", "last_session_notes": null}
  ```

## 5. Commit and present

Commit the directory to the gumbo repo, then show the path, the questions with their output files, and any shared contract. Do not start investigating: the plan is reviewed first (`/research-review`, or a Codex loop), then `/research-resume` runs it.
