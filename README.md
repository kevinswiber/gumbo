# gumbo

Version-controlled development thoughts, plans, research, and issues -- separated from code repos.

This is my personal workflow tool. If you're here, you should watch a clip from this cooking show I grew up with:

[![Gumbo clip](https://img.youtube.com/vi/oScmodG_riM/0.jpg)](https://youtu.be/oScmodG_riM?si=TJcdd51-S5djM0oC)

## Why

Keep your inner dev loop artifacts (implementation plans, research, issue tracking) out of your code repos while still version-controlling them. Each project gets a `.gumbo` symlink pointing to a per-project directory under `~/.gumbo`.

## Workflow

The file system acts as scratch space for each phase of the inner dev loop, so you don't lose anything between steps -- each skill reads what it needs from disk and runs independently. You can start every step with a fresh context.

### 1. Research

Run `/research-create` to create a research plan. This produces a list of research tasks -- things like searching the web for an issue, reviewing codebases, combing through git logs, or going through issues and PRs. Research is instructed to find info on the what, where, how, and why.

Run `/research-resume` to execute the plan. It runs the investigations in parallel (subagents by default, or whatever coordination capability best fits) -- each writes its findings to a file in the research subdirectory -- then synthesizes them. From there you can edit, refine, have conversations, or do more research. `/research-review` checks the result for grounding, internal consistency, and synthesis fidelity before you rely on it.

When research reaches a conclusion worth recording, `/adr-create` turns the synthesis into a durable Architecture Decision Record -- the *what, why, and what-was-rejected* of a decision. ADR drafts live in the research dir and land in the code repo's `docs/adr/` via an implementation plan; a landed decision is extended with an appended amendment, never rewritten.

### 2. Plan

Run `/plan-create` to create an implementation plan in `.gumbo/plans/`. Each plan gets its own subdirectory containing `implementation-plan.md`, `task-list.md`, and a `tasks/` directory with a file per task. Tasks are grouped into phases, with commits after each phase for more atomic changes. For large or multi-module plans, it can also write an `architecture-brief.md` (module map, task ownership, cross-task seams).

You can base a plan on previous research: `/plan-create research 0044`. `/plan-review` checks a plan for correctness, feasibility, and internal consistency before you implement it.

### 3. Implement

Run `/plan-resume` to start implementation -- ideally from a fresh context, since it reads the plan from disk. Along the way, it records findings in the plan's `findings/` subdirectory -- deviations from the plan, new information, things that came up.

### 4. Triage findings

Findings accumulate in the plan's `findings/` subdirectory as you implement (step 3) -- deviations, new information, edges that surfaced. If they weren't captured along the way, `/plan-findings-create` reviews the completed phases and extracts them retroactively, so nothing is lost before triage.

Run `/plan-findings-resume` to triage them. Each finding is routed to where it belongs: a tracked **issue** in `.gumbo/issues/` (a real bug or follow-up), a **research** update (a question that needs investigation before it can be acted on), or a recorded **no-action** note (a design decision worth keeping but needing no change). Issues might in turn spawn more research or direct fixes. Triaging is what keeps the signal from implementation from evaporating once the plan is archived -- the findings outlive the plan as durable issues and research.

### 5. Archive

When done, run `/research-archive` or `/plan-archive` to move completed work into the `.gumbo/{research,plans}/archive/` directory.

### Running in parallel

No phase depends on another. You can have multiple research and implementation plans running at the same time, or nest them -- research informing plans informing more research. Each has its own state file tracking progress.

## Coordinating across plans, decisions, and projects

The loop above is for one piece of work. When work spans many plans, research efforts, and decisions -- over many sessions, or across several repos -- three skills hold it together:

- **`/roadmap-create`** -- a living roadmap that sequences the plans, research, and decisions into milestones, tracks per-row status, and records dependencies and risks. The single place "what's next and why" lives; rows link to the plan/research/ADR that fulfills them.
- **`/coordinator`** -- operate or resume a long-lived coordinator role. You orchestrate and sequence the work -- creating plans/research/ADRs, processing external reviews against source, recording landings, keeping the roadmap true -- without implementing it yourself (implementation happens in separate `/plan-resume` sessions). The role survives across sessions through durable handoff, findings-ledger, and roadmap records.
- **`/handoff`** -- when context grows large, generate a paste-ready resume prompt that flushes in-flight state to those durable records, then points a fresh session at them and names the single next action. A clean break beats a session running on fumes.

Two cross-cutting habits keep all of this trustworthy: decisions are recorded as they're made (`/adr-create`), and artifacts are double-checked with `/plan-review` / `/research-review` -- both before they're relied on and as they're iterated, since a reference left stale by an edit is cheap to fix now and expensive later.

## Project structure

Run `/gumbo-init` from your code directory to set things up. Each code repo gets a `.gumbo` symlink that points to a project directory under `~/.gumbo`:

```
~/src/myapp/
├── .gumbo -> ~/.gumbo/projects/myapp   # Symlink to data directory
├── AGENTS.local.md                      # Local agent context, ignored
├── CLAUDE.local.md -> AGENTS.local.md   # Claude compatibility symlink
├── .gitignore                          # Contains "/.gumbo" and local instruction files
└── ...
```

The data lives outside the code repo so it can be version-controlled separately:

```
~/.gumbo/                               # Data root (version-controllable)
└── projects/
    └── myapp/
        ├── config.json                 # Project metadata and backlink
        ├── AGENTS.local.md -> <plugin-root>/plugins/gumbo/AGENTS.local.md
        ├── CLAUDE.local.md -> AGENTS.local.md
        ├── plans/
        ├── research/
        └── issues/
```

`config.json` stores the project name, working directory, and data root so you can trace in both directions.

## Setup

## Install plugins

Add the marketplace and install plugins:

```bash
claude plugin marketplace add kevinswiber/gumbo
claude plugin install gumbo@gumbo
```

## Initialize a project

Run `/gumbo-init` from your code directory. You can optionally pass a project name:

```
/gumbo-init myapp
```

Without a name, it uses the directory name. You can also run the script directly:

```bash
plugins/gumbo/skills/gumbo-init/scripts/init.sh ~/.gumbo ~/src/myproject
plugins/gumbo/skills/gumbo-init/scripts/init.sh ~/.gumbo ~/src/myproject myapp
```

This will:

1. Create `~/.gumbo/projects/myapp/` (if it doesn't exist)
2. Copy the template directories (`plans/`, `research/`, `issues/`) with their `AGENTS.md` files and `CLAUDE.md` compatibility symlinks
3. Write `config.json` with the project name, working directory, and data root
4. Symlink `.gumbo/AGENTS.local.md` to the shared copy in the gumbo plugin
5. Create or update project-local `AGENTS.local.md`, with `CLAUDE.local.md` as a compatibility symlink
6. Create a symlink at `~/src/myproject/.gumbo` pointing to the data directory
7. Add `/.gumbo`, `AGENTS.local.md`, and `CLAUDE.local.md` to the project's `.gitignore`

## Skills

### plan

- `/plan-create` -- Create an implementation plan
- `/plan-resume` -- Resume an in-progress plan
- `/plan-review` -- Review a plan for correctness, feasibility, and consistency
- `/plan-archive` -- Archive a completed plan
- `/plan-cancel` -- Cancel a plan
- `/plan-findings-create` -- Extract findings from completed phases
- `/plan-findings-resume` -- Triage findings into issues/research

### research

- `/research-create` -- Create a research plan with parallel investigation
- `/research-resume` -- Resume or synthesize research
- `/research-review` -- Review research for grounding, consistency, and synthesis fidelity
- `/research-archive` -- Archive completed research
- `/research-cancel` -- Cancel research

### decisions

- `/adr-create` -- Draft or amend an Architecture Decision Record from a synthesis or design decision

### roadmap

- `/roadmap-create` -- Create and maintain a milestone roadmap that sequences plans, research, and decisions

### coordination

- `/coordinator` -- Operate or resume a long-lived cross-project coordinator role
- `/handoff` -- Generate a paste-ready resume prompt for a fresh session when context grows large

### gumbo

- `/gumbo-init` -- Initialize a gumbo directory for a project

## AGENTS.local.md

`plugins/gumbo/AGENTS.local.md` contains shared agent instructions (planning, research, and issue workflows) that apply to all projects. Each project gets a symlink at `.gumbo/AGENTS.local.md` pointing to this single source of truth, so updates propagate to every project automatically. `CLAUDE.local.md` is kept as a compatibility symlink for Claude-specific tooling.

## Directories

### plans/

Implementation plans with task lists, TDD workflows, and progress tracking. See the template `plans/AGENTS.md` for conventions.

### research/

Research investigations with parallel question-based exploration. See the template `research/AGENTS.md` for conventions.

### issues/

Issue sets sourced from plan findings or direct observation. See the template `issues/AGENTS.md` for conventions.
