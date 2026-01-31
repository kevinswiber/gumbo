#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/template"

usage() {
    echo "Usage: $0 <gumbo-root> <project-path> [project-name]"
    echo ""
    echo "Initialize a gumbo directory for a project and symlink it."
    echo ""
    echo "Arguments:"
    echo "  <gumbo-root>    Path to the gumbo data root (e.g. ~/.gumbo)"
    echo "  <project-path>  Path to the project (e.g. ~/src/myproject)"
    echo "  [project-name]  Optional name for the project (defaults to directory name)"
    echo ""
    echo "Environment:"
    echo "  GUMBO_ROOT      Overrides the <gumbo-root> argument"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.gumbo ~/src/myproject"
    echo "  $0 ~/.gumbo ~/src/myproject myapp"
    exit 1
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
fi

GUMBO_ROOT="${GUMBO_ROOT:-$1}"
GUMBO_ROOT="$(cd "$GUMBO_ROOT" && pwd)"

PROJECT_PATH="$(cd "$2" && pwd)"
PROJECT_NAME="${3:-$(basename "$PROJECT_PATH")}"
GUMBO_PROJECT_DIR="$GUMBO_ROOT/projects/$PROJECT_NAME"
SYMLINK_PATH="$PROJECT_PATH/.gumbo"

# Check if .gumbo exists but is not a symlink
if [[ -e "$SYMLINK_PATH" && ! -L "$SYMLINK_PATH" ]]; then
    echo "Error: $SYMLINK_PATH exists but is not a symlink."
    echo "Move or remove it before running init."
    exit 1
fi

# Check if symlink exists and points somewhere unexpected
if [[ -L "$SYMLINK_PATH" ]]; then
    existing_target="$(readlink "$SYMLINK_PATH")"
    if [[ "$existing_target" != "$GUMBO_PROJECT_DIR" ]]; then
        echo "Error: $SYMLINK_PATH already exists but points to $existing_target"
        echo "Expected: $GUMBO_PROJECT_DIR"
        exit 1
    fi
fi

# Create the gumbo project directory if it doesn't exist
mkdir -p "$GUMBO_PROJECT_DIR"

# Ensure all template files/directories are present (don't overwrite existing)
for item in "$TEMPLATE_DIR"/*; do
    name="$(basename "$item")"
    if [[ ! -e "$GUMBO_PROJECT_DIR/$name" ]]; then
        cp -r "$item" "$GUMBO_PROJECT_DIR/$name"
        echo "Added missing template item: $name"
    fi
done

# Write config.json with project metadata
CONFIG_FILE="$GUMBO_PROJECT_DIR/config.json"
if [[ ! -e "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "name": "$PROJECT_NAME",
  "workingDirectory": "$PROJECT_PATH",
  "root": "$GUMBO_PROJECT_DIR"
}
EOF
    echo "Created config.json"
else
    # Update workingDirectory in case the project moved
    EXISTING_WD="$(jq -r '.workingDirectory // ""' "$CONFIG_FILE")"
    if [[ "$EXISTING_WD" != "$PROJECT_PATH" ]]; then
        jq --arg wd "$PROJECT_PATH" '.workingDirectory = $wd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "Updated workingDirectory in config.json"
    fi
fi

# Ensure AGENTS.local.md symlink exists
if [[ ! -e "$GUMBO_PROJECT_DIR/AGENTS.local.md" ]]; then
    ln -s "$PLUGIN_ROOT/AGENTS.local.md" "$GUMBO_PROJECT_DIR/AGENTS.local.md"
    echo "Added AGENTS.local.md symlink"
fi

# Create the project symlink if it doesn't exist
if [[ ! -L "$SYMLINK_PATH" ]]; then
    ln -s "$GUMBO_PROJECT_DIR" "$SYMLINK_PATH"
    echo "Created symlink: $SYMLINK_PATH -> $GUMBO_PROJECT_DIR"
fi

# Add /.gumbo to project's .gitignore if not already there
GITIGNORE="$PROJECT_PATH/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -qx '/.gumbo' "$GITIGNORE"; then
        echo '/.gumbo' >> "$GITIGNORE"
        echo "Added /.gumbo to $GITIGNORE"
    fi
else
    echo '/.gumbo' > "$GITIGNORE"
    echo "Created $GITIGNORE with /.gumbo entry"
fi

echo "Done. Project '$PROJECT_NAME' is ready."
