#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template"

usage() {
    echo "Usage: $0 <gumbo-root> <project-path>"
    echo ""
    echo "Initialize a gumbo directory for a project and symlink it."
    echo ""
    echo "Arguments:"
    echo "  <gumbo-root>    Path to the gumbo data root (e.g. ~/.gumbo)"
    echo "  <project-path>  Path to the project (e.g. ~/src/myproject)"
    echo ""
    echo "Environment:"
    echo "  GUMBO_ROOT      Overrides the <gumbo-root> argument"
    echo ""
    echo "Example:"
    echo "  $0 ~/.gumbo ~/src/myproject"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

GUMBO_ROOT="${GUMBO_ROOT:-$1}"
GUMBO_ROOT="$(cd "$GUMBO_ROOT" && pwd)"

PROJECT_PATH="$(cd "$2" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_PATH")"
GUMBO_PROJECT_DIR="$GUMBO_ROOT/projects/$PROJECT_NAME"
SYMLINK_PATH="$PROJECT_PATH/.gumbo"

# Check if symlink already exists and points to the right place
if [[ -L "$SYMLINK_PATH" ]]; then
    existing_target="$(readlink "$SYMLINK_PATH")"
    if [[ "$existing_target" == "$GUMBO_PROJECT_DIR" ]]; then
        echo "Already initialized: $SYMLINK_PATH -> $GUMBO_PROJECT_DIR"
        exit 0
    else
        echo "Error: $SYMLINK_PATH already exists but points to $existing_target"
        echo "Expected: $GUMBO_PROJECT_DIR"
        exit 1
    fi
fi

# Check if .gumbo exists but is not a symlink
if [[ -e "$SYMLINK_PATH" ]]; then
    echo "Error: $SYMLINK_PATH exists but is not a symlink."
    echo "Move or remove it before running init."
    exit 1
fi

# Create the gumbo project directory if it doesn't exist
if [[ -d "$GUMBO_PROJECT_DIR" ]]; then
    echo "Gumbo directory already exists: $GUMBO_PROJECT_DIR"
else
    echo "Creating gumbo directory: $GUMBO_PROJECT_DIR"
    mkdir -p "$GUMBO_PROJECT_DIR"
    cp -r "$TEMPLATE_DIR"/* "$GUMBO_PROJECT_DIR/"
    ln -s "${CLAUDE_PLUGIN_ROOT}/AGENTS.local.md" "$GUMBO_PROJECT_DIR/AGENTS.local.md"
    echo "Copied template to $GUMBO_PROJECT_DIR"
fi

# Create the symlink
ln -s "$GUMBO_PROJECT_DIR" "$SYMLINK_PATH"
echo "Created symlink: $SYMLINK_PATH -> $GUMBO_PROJECT_DIR"

# Add .gumbo to project's .gitignore if not already there
GITIGNORE="$PROJECT_PATH/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -qx '.gumbo' "$GITIGNORE"; then
        echo '.gumbo' >> "$GITIGNORE"
        echo "Added .gumbo to $GITIGNORE"
    fi
else
    echo '.gumbo' > "$GITIGNORE"
    echo "Created $GITIGNORE with .gumbo entry"
fi

echo "Done. Project '$PROJECT_NAME' is ready."
