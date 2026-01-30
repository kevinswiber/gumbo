# gumbo

Version-controlled development thoughts, plans, research, and issues -- separated from code repos.

## Why

Keep your inner dev loop artifacts (implementation plans, research, issue tracking) out of your code repos while still version-controlling them. Each project gets a `.gumbo` symlink pointing to a per-project directory under `~/.gumbo`.

## Structure

```
~/.gumbo/                        # Data root (version-controllable)
└── projects/
    └── mmdflux/
        ├── AGENTS.local.md -> <plugin-root>/plugins/gumbo/AGENTS.local.md
        ├── plans/
        ├── research/
        └── issues/

gumbo/                           # Plugin/marketplace repo
├── .claude-plugin/
│   └── marketplace.json         # Plugin marketplace catalog
└── plugins/
    └── gumbo/                   # All skills in one plugin
        ├── .claude-plugin/
        │   └── plugin.json
        ├── AGENTS.local.md      # Shared agent rules symlinked into each project
        └── skills/
            ├── gumbo-init/      # Project initialization
            ├── plan-create/     # Implementation planning
            ├── plan-resume/
            ├── plan-archive/
            ├── plan-cancel/
            ├── plan-findings-create/
            ├── plan-findings-resume/
            ├── research-create/ # Research investigations
            ├── research-resume/
            ├── research-archive/
            └── research-cancel/
```

## Setup

Each directory in `~/.gumbo/projects/` corresponds to a code repo. For example:

- `~/.gumbo/projects/myapp/` serves `~/src/myapp/`
- `~/.gumbo/projects/webapp/` serves `~/src/webapp/`

The code repo has `.gumbo` in its `.gitignore` and a symlink:

```
~/src/myapp/.gumbo -> ~/.gumbo/projects/myapp
```

## Install plugins

Add the marketplace and install plugins:

```bash
claude plugin marketplace add kevinswiber/gumbo
claude plugin install gumbo@gumbo
```

## Initialize a project

Use the `/gumbo:init` skill or run the script directly:

```bash
plugins/gumbo/skills/gumbo-init/scripts/init.sh ~/.gumbo ~/src/myproject
```

This will:

1. Create `~/.gumbo/projects/myproject/` (if it doesn't exist)
2. Copy the template directories (`plans/`, `research/`, `issues/`) with their `CLAUDE.md` files
3. Symlink `AGENTS.local.md` to the shared copy in the gumbo plugin
4. Create a symlink at `~/src/myproject/.gumbo` pointing to the gumbo directory
5. Add `.gumbo` to the project's `.gitignore`

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
