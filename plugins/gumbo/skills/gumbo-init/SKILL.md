---
name: gumbo:init
description: Initialize a gumbo directory for the current project, creating a template in ~/.gumbo and a symlink in the project repo
allowed-tools: Bash(./scripts/init.sh:*), Read, Write, Edit
---

## Your task

1. Run the gumbo init script, passing the gumbo root and the current working directory as arguments:

```
./scripts/init.sh ~/.gumbo "$PWD"
```

2. Ensure `CLAUDE.local.md` exists in the project root (`$PWD/CLAUDE.local.md`). If it doesn't exist, create it.

3. Ensure `CLAUDE.local.md` contains a reference to `.gumbo/AGENTS.local.md`. If the file already has this reference, leave it alone. Otherwise, add the following line:

```
@.gumbo/AGENTS.local.md
```

Report the output to the user. Do not use any other tools or do anything else.
