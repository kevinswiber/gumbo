# gumbo

Version-controlled development thoughts, plans, research, and issues -- separated from code repos.

This is my personal workflow tool. If you're here, you should watch a clip from this cooking show I grew up with:

[![Gumbo clip](https://img.youtube.com/vi/oScmodG_riM/0.jpg)](https://youtu.be/oScmodG_riM?si=TJcdd51-S5djM0oC)

## Why

Keep your inner dev loop artifacts (implementation plans, research, issue tracking) out of your code repos while still version-controlling them. Each project gets a `.gumbo` symlink pointing to a per-project directory under `~/.gumbo`.

## Workflow

The file system acts as scratch space for each phase of the inner dev loop so you don't lose context between `/clear` calls. Each skill runs independently -- `/clear` between steps.

### 1. Research

Run `/research:create` to create a research plan. This produces a list of research tasks -- things like searching the web for an issue, reviewing codebases, combing through git logs, or going through issues and PRs. Research is instructed to find info on the what, where, how, and why.

Run `/research:resume` to execute the plan. This launches subagents in parallel to carry out each research task. Each subagent writes its findings to a file in the research subdirectory. From there, you can edit, refine, have conversations, or do more research.

### 2. Plan

Run `/plan:create` to create an implementation plan in `.gumbo/plans/`. Each plan gets its own subdirectory containing `implementation-plan.md`, `task-list.md`, and a `tasks/` directory with a file per task. Tasks are grouped into phases, with commits after each phase for more atomic changes.

You can base a plan on previous research: `/plan:create research 0044`.

### 3. Implement

Run `/clear` if you haven't already, then `/plan:resume` to start implementation. Along the way, it records findings in the plan's `findings/` subdirectory -- deviations from the plan, new information, things that came up.

### 4. Triage findings

After everything's committed, run `/plan:findings-resume` to create issues in `.gumbo/issues/` from the findings. Those issues might spawn more research plans or direct fixes.

### 5. Archive

When done, run `/research:archive` or `/plan:archive` to move completed work into the `.gumbo/{research,plans}/archive/` directory.

### Running in parallel

No phase depends on another. You can have multiple research and implementation plans running at the same time, or nest them -- research informing plans informing more research. Each has its own state file tracking progress.

## Project structure

Run `/gumbo:init` from your code directory to set things up. Each code repo gets a `.gumbo` symlink that points to a project directory under `~/.gumbo`:

```
~/src/myapp/
├── .gumbo -> ~/.gumbo/projects/myapp   # Symlink to data directory
├── .gitignore                          # Contains ".gumbo"
└── ...
```

The data lives outside the code repo so it can be version-controlled separately:

```
~/.gumbo/                               # Data root (version-controllable)
└── projects/
    └── myapp/
        ├── config.json                 # Project metadata and backlink
        ├── AGENTS.local.md -> <plugin-root>/plugins/gumbo/AGENTS.local.md
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

Run `/gumbo:init` from your code directory. You can optionally pass a project name:

```
/gumbo:init myapp
```

Without a name, it uses the directory name. You can also run the script directly:

```bash
plugins/gumbo/skills/gumbo-init/scripts/init.sh ~/.gumbo ~/src/myproject
plugins/gumbo/skills/gumbo-init/scripts/init.sh ~/.gumbo ~/src/myproject myapp
```

This will:

1. Create `~/.gumbo/projects/myapp/` (if it doesn't exist)
2. Copy the template directories (`plans/`, `research/`, `issues/`) with their `CLAUDE.md` files
3. Write `config.json` with the project name, working directory, and data root
4. Symlink `AGENTS.local.md` to the shared copy in the gumbo plugin
5. Create a symlink at `~/src/myproject/.gumbo` pointing to the data directory
6. Add `.gumbo` to the project's `.gitignore`

## Skills

### plan

- `/plan:create` -- Create an implementation plan
- `/plan:resume` -- Resume an in-progress plan
- `/plan:archive` -- Archive a completed plan
- `/plan:cancel` -- Cancel a plan
- `/plan:findings-create` -- Extract findings from completed phases
- `/plan:findings-resume` -- Triage findings into issues/research

### research

- `/research:create` -- Create a research plan with parallel investigation
- `/research:resume` -- Resume or synthesize research
- `/research:archive` -- Archive completed research
- `/research:cancel` -- Cancel research

### gumbo

- `/gumbo:init` -- Initialize a gumbo directory for a project

## AGENTS.local.md

`plugins/gumbo/AGENTS.local.md` contains shared agent instructions (planning, research, and issue workflows) that apply to all projects. Each project gets a symlink at `.gumbo/AGENTS.local.md` pointing to this single source of truth, so updates propagate to every project automatically.

## Directories

### plans/

Implementation plans with task lists, TDD workflows, and progress tracking. See the template `plans/CLAUDE.md` for conventions.

### research/

Research investigations with parallel question-based exploration. See the template `research/CLAUDE.md` for conventions.

### issues/

Issue sets sourced from plan findings or direct observation. See the template `issues/CLAUDE.md` for conventions.
