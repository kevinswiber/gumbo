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

5. Check the project's `.gitignore` for `CLAUDE.local.md` and `AGENTS.local.md`. If either is missing from `.gitignore`, add it. These are local/private files that shouldn't be committed to the code repo.

6. After successful initialization, remind the user to add the gumbo data directory to their Claude Code context so it's available across sessions. Tell them to run:

```
/add-dir ~/.gumbo
```

They can add it to either the current project or to their user-scoped settings (`~/.claude/settings.json`) if they want it available in all projects.

Report the output to the user. Do not use any other tools or do anything else.
