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

ensure_gitignore_entry() {
    local entry="$1"

    if ! grep -qxF "$entry" "$GITIGNORE"; then
        echo "$entry" >> "$GITIGNORE"
        echo "Added $entry to $GITIGNORE"
    fi
}

ensure_relative_symlink() {
    local link_path="$1"
    local target="$2"
    local label="$3"

    if [[ -L "$link_path" ]]; then
        if [[ "$(readlink "$link_path")" != "$target" ]]; then
            rm "$link_path"
            ln -s "$target" "$link_path"
            echo "Updated $label symlink"
        fi
    elif [[ ! -e "$link_path" ]]; then
        ln -s "$target" "$link_path"
        echo "Added $label symlink"
    fi
}

ensure_agent_instruction_pair() {
    local dir="$1"
    local name
    name="$(basename "$dir")"
    local primary="$dir/AGENTS.md"
    local compat="$dir/CLAUDE.md"
    local template_primary="$TEMPLATE_DIR/$name/AGENTS.md"

    mkdir -p "$dir"

    if [[ -L "$primary" && "$(readlink "$primary")" == "CLAUDE.md" && -f "$compat" && ! -L "$compat" ]]; then
        rm "$primary"
        mv "$compat" "$primary"
        ln -s "AGENTS.md" "$compat"
        echo "Reversed $name instructions: AGENTS.md is primary, CLAUDE.md is the symlink"
        return
    fi

    if [[ ! -e "$primary" && ! -L "$primary" ]]; then
        if [[ -f "$compat" && ! -L "$compat" ]]; then
            mv "$compat" "$primary"
            echo "Renamed $name/CLAUDE.md to $name/AGENTS.md"
        elif [[ -f "$template_primary" ]]; then
            cp "$template_primary" "$primary"
            echo "Added missing $name/AGENTS.md"
        fi
    fi

    if [[ -L "$compat" ]]; then
        if [[ "$(readlink "$compat")" != "AGENTS.md" ]]; then
            rm "$compat"
            ln -s "AGENTS.md" "$compat"
            echo "Updated $name/CLAUDE.md compatibility symlink"
        fi
    elif [[ ! -e "$compat" ]]; then
        ln -s "AGENTS.md" "$compat"
        echo "Added $name/CLAUDE.md compatibility symlink"
    elif [[ -f "$compat" && -f "$primary" ]] && cmp -s "$compat" "$primary"; then
        rm "$compat"
        ln -s "AGENTS.md" "$compat"
        echo "Replaced duplicate $name/CLAUDE.md with compatibility symlink"
    fi
}

ensure_project_local_instructions() {
    local primary="$PROJECT_PATH/AGENTS.local.md"
    local compat="$PROJECT_PATH/CLAUDE.local.md"
    local reference="@.gumbo/AGENTS.local.md"

    if [[ -L "$primary" && "$(readlink "$primary")" == "CLAUDE.local.md" && -f "$compat" && ! -L "$compat" ]]; then
        rm "$primary"
        mv "$compat" "$primary"
        ln -s "AGENTS.local.md" "$compat"
        echo "Reversed local instructions: AGENTS.local.md is primary, CLAUDE.local.md is the symlink"
    elif [[ ! -e "$primary" && ! -L "$primary" ]]; then
        if [[ -f "$compat" && ! -L "$compat" ]]; then
            mv "$compat" "$primary"
            echo "Renamed CLAUDE.local.md to AGENTS.local.md"
        else
            printf '%s\n' "$reference" > "$primary"
            echo "Created AGENTS.local.md"
        fi
    fi

    if [[ -f "$primary" && ! -L "$primary" ]]; then
        if ! grep -qxF "$reference" "$primary"; then
            if [[ -s "$primary" ]]; then
                printf '\n' >> "$primary"
            fi
            printf '%s\n' "$reference" >> "$primary"
            echo "Added .gumbo/AGENTS.local.md reference to AGENTS.local.md"
        fi
    fi

    if [[ -L "$compat" ]]; then
        if [[ "$(readlink "$compat")" != "AGENTS.local.md" ]]; then
            rm "$compat"
            ln -s "AGENTS.local.md" "$compat"
            echo "Updated CLAUDE.local.md compatibility symlink"
        fi
    elif [[ ! -e "$compat" ]]; then
        ln -s "AGENTS.local.md" "$compat"
        echo "Added CLAUDE.local.md compatibility symlink"
    elif [[ -f "$compat" && -f "$primary" ]] && cmp -s "$compat" "$primary"; then
        rm "$compat"
        ln -s "AGENTS.local.md" "$compat"
        echo "Replaced duplicate CLAUDE.local.md with compatibility symlink"
    fi
}

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

for section in plans research issues; do
    ensure_agent_instruction_pair "$GUMBO_PROJECT_DIR/$section"
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
if [[ -L "$GUMBO_PROJECT_DIR/AGENTS.local.md" ]]; then
    if [[ "$(readlink "$GUMBO_PROJECT_DIR/AGENTS.local.md")" != "$PLUGIN_ROOT/AGENTS.local.md" ]]; then
        rm "$GUMBO_PROJECT_DIR/AGENTS.local.md"
        ln -s "$PLUGIN_ROOT/AGENTS.local.md" "$GUMBO_PROJECT_DIR/AGENTS.local.md"
        echo "Updated AGENTS.local.md symlink"
    fi
elif [[ ! -e "$GUMBO_PROJECT_DIR/AGENTS.local.md" ]]; then
    ln -s "$PLUGIN_ROOT/AGENTS.local.md" "$GUMBO_PROJECT_DIR/AGENTS.local.md"
    echo "Added AGENTS.local.md symlink"
fi

ensure_relative_symlink "$GUMBO_PROJECT_DIR/CLAUDE.local.md" "AGENTS.local.md" "CLAUDE.local.md compatibility"

# Create the project symlink if it doesn't exist
if [[ ! -L "$SYMLINK_PATH" ]]; then
    ln -s "$GUMBO_PROJECT_DIR" "$SYMLINK_PATH"
    echo "Created symlink: $SYMLINK_PATH -> $GUMBO_PROJECT_DIR"
fi

# Add /.gumbo to project's .gitignore if not already there
GITIGNORE="$PROJECT_PATH/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
    touch "$GITIGNORE"
    echo "Created $GITIGNORE"
fi

ensure_project_local_instructions
ensure_gitignore_entry '/.gumbo'
ensure_gitignore_entry 'AGENTS.local.md'
ensure_gitignore_entry 'CLAUDE.local.md'

echo "Done. Project '$PROJECT_NAME' is ready."
