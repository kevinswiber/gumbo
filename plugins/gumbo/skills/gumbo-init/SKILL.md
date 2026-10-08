---
name: gumbo-init
description: Initialize a gumbo directory for the current project, creating a template in ~/.gumbo and a symlink in the project repo
allowed-tools: Bash(*/gumbo-init/scripts/init.sh:*), Read, Write, Edit
---

## Your task

1. If the user gave a project name (`/gumbo-init myapp`), pass it as the third argument; otherwise omit it and the script uses the directory name.

2. Run the init script by its absolute path, without changing directory, so `$PWD` is the user's project:

```
"${CLAUDE_PLUGIN_ROOT}/skills/gumbo-init/scripts/init.sh" ~/.gumbo "$PWD" [project-name]
```

If `CLAUDE_PLUGIN_ROOT` is unset, use the path this skill was loaded from (`<plugin root>/skills/gumbo-init/scripts/init.sh`).

The script is idempotent. Every project symlinks its `AGENTS.local.md` to `~/.gumbo/AGENTS.local.md`. When the plugin runs from a source checkout, that root entry is a symlink into the checkout and tracks it live; when it runs from a managed install under `~/.claude/plugins`, it is a copy refreshed on every run, so rerun this skill after a plugin update. The script also reports when a project's `plans/`, `research/`, or `issues/AGENTS.md` has drifted from the plugin template; it never overwrites those project copies.

3. After a first initialization, remind the user to add the gumbo data directory to their Claude Code context:

```
/add-dir ~/.gumbo
```

They can add it to the current project or to their user settings (`~/.claude/settings.json`) for all projects.

Report the script output to the user. Do not use any other tools or do anything else.
