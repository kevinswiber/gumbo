#!/usr/bin/env bash
set -euo pipefail

THOUGHTS_ROOT="$HOME/src/thoughts"
TEMPLATE_DIR="$THOUGHTS_ROOT/template"

usage() {
    echo "Usage: $0 <project-path>"
    echo ""
    echo "Initialize a thoughts directory for a project and symlink it."
    echo ""
    echo "Example:"
    echo "  $0 ~/src/myproject"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

PROJECT_PATH="$(cd "$1" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_PATH")"
THOUGHTS_PROJECT_DIR="$THOUGHTS_ROOT/src/$PROJECT_NAME"
SYMLINK_PATH="$PROJECT_PATH/.thoughts"

# Check if symlink already exists and points to the right place
if [[ -L "$SYMLINK_PATH" ]]; then
    existing_target="$(readlink "$SYMLINK_PATH")"
    if [[ "$existing_target" == "$THOUGHTS_PROJECT_DIR" ]]; then
        echo "Already initialized: $SYMLINK_PATH -> $THOUGHTS_PROJECT_DIR"
        exit 0
    else
        echo "Error: $SYMLINK_PATH already exists but points to $existing_target"
        echo "Expected: $THOUGHTS_PROJECT_DIR"
        exit 1
    fi
fi

# Check if .thoughts exists but is not a symlink
if [[ -e "$SYMLINK_PATH" ]]; then
    echo "Error: $SYMLINK_PATH exists but is not a symlink."
    echo "Move or remove it before running init."
    exit 1
fi

# Create the thoughts project directory if it doesn't exist
if [[ -d "$THOUGHTS_PROJECT_DIR" ]]; then
    echo "Thoughts directory already exists: $THOUGHTS_PROJECT_DIR"
else
    echo "Creating thoughts directory: $THOUGHTS_PROJECT_DIR"
    mkdir -p "$THOUGHTS_PROJECT_DIR"
    cp -r "$TEMPLATE_DIR"/* "$THOUGHTS_PROJECT_DIR/"
    ln -s ../../rules/AGENTS.local.md "$THOUGHTS_PROJECT_DIR/AGENTS.local.md"
    echo "Copied template to $THOUGHTS_PROJECT_DIR"
fi

# Create the symlink
ln -s "$THOUGHTS_PROJECT_DIR" "$SYMLINK_PATH"
echo "Created symlink: $SYMLINK_PATH -> $THOUGHTS_PROJECT_DIR"

# Add .thoughts to project's .gitignore if not already there
GITIGNORE="$PROJECT_PATH/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -qx '.thoughts' "$GITIGNORE"; then
        echo '.thoughts' >> "$GITIGNORE"
        echo "Added .thoughts to $GITIGNORE"
    fi
else
    echo '.thoughts' > "$GITIGNORE"
    echo "Created $GITIGNORE with .thoughts entry"
fi

echo "Done. Project '$PROJECT_NAME' is ready."
