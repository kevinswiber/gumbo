---
name: gumbo:init
description: Initialize a gumbo directory for the current project, creating a template in ~/.gumbo and a symlink in the project repo
allowed-tools: Bash(*/gumbo-init/scripts/init.sh:*), Read, Write, Edit
---

## Your task

1. Check if the user provided a project name (e.g. `/gumbo:init myapp`). If they did, pass it as the third argument to the init script. If not, omit the third argument and the script will default to the directory name.

2. Run the gumbo init script:

```
# With project name:
./scripts/init.sh ~/.gumbo "$PWD" <project-name>

# Without project name (defaults to directory name):
./scripts/init.sh ~/.gumbo "$PWD"
```

3. Ensure `CLAUDE.local.md` exists in the project root (`$PWD/CLAUDE.local.md`). If it doesn't exist, create it.

4. Ensure `CLAUDE.local.md` contains a reference to `.gumbo/AGENTS.local.md`. If the file already has this reference, leave it alone. Otherwise, add the following line:

```
@.gumbo/AGENTS.local.md
```

Report the output to the user. Do not use any other tools or do anything else.
