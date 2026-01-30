---
name: init
description: Initialize a thoughts directory for the current project, creating a template in ~/src/thoughts and a symlink in the project repo
allowed-tools: Bash(~/src/thoughts/init.sh:*), Read, Write, Edit
---

## Your task

1. Run the thoughts init script, passing the current working directory as the project path:

```
~/src/thoughts/init.sh "$PWD"
```

2. Ensure `CLAUDE.local.md` exists in the project root (`$PWD/CLAUDE.local.md`). If it doesn't exist, create it.

3. Ensure `CLAUDE.local.md` contains a reference to `.thoughts/AGENTS.local.md`. If the file already has this reference, leave it alone. Otherwise, add the following line:

```
@.thoughts/AGENTS.local.md
```

Report the output to the user. Do not use any other tools or do anything else.
