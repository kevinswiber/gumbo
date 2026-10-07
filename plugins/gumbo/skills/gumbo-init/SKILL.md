---
name: gumbo-init
description: Initialize a gumbo directory for the current project, creating a template in ~/.gumbo and a symlink in the project repo
allowed-tools: Bash(*/gumbo-init/scripts/init.sh:*), Read, Write, Edit
---

## Your task

1. If the user gave a project name (`/gumbo-init myapp`), pass it as the third argument; otherwise omit it and the script uses the directory name.

2. Run the init script from this skill's directory:

```
./scripts/init.sh ~/.gumbo "$PWD" [project-name]
```

The script is idempotent. Running it again on an initialized project refreshes the shared conventions copy at `~/.gumbo/AGENTS.local.md` (every project symlinks to it) and reports when a project's `plans/`, `research/`, or `issues/AGENTS.md` has drifted from the plugin template; it never overwrites those project copies.

3. After a first initialization, remind the user to add the gumbo data directory to their Claude Code context:

```
/add-dir ~/.gumbo
```

They can add it to the current project or to their user settings (`~/.claude/settings.json`) for all projects.

Report the script output to the user. Do not use any other tools or do anything else.
