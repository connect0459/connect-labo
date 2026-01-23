#!/usr/bin/env bash

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.claude"

echo "Claude configuration sync script"
echo "Source: ${SCRIPT_DIR}"
echo "Target: ${TARGET_DIR}"
echo ""

# Create target directory if it does not exist
if [ ! -d "${TARGET_DIR}" ]; then
    echo "Creating target directory: ${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
fi

# Create agent-docs directory
if [ ! -d "${TARGET_DIR}/agent-docs" ]; then
    echo "Creating agent-docs directory"
    mkdir -p "${TARGET_DIR}/agent-docs"
fi

# Sync CLAUDE.md
echo "Syncing CLAUDE.md"
cp "${SCRIPT_DIR}/CLAUDE.md" "${TARGET_DIR}/CLAUDE.md"

# Sync agent-docs directory (delete files not in source)
echo "Syncing agent-docs directory"
rsync -a --delete "${SCRIPT_DIR}/agent-docs/" "${TARGET_DIR}/agent-docs/"

# Sync permissions field from settings.json
if [ -f "${SCRIPT_DIR}/settings.json" ]; then
    echo "Syncing permissions from settings.json"

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install jq to sync permissions."
        echo "  brew install jq"
        exit 1
    fi

    # Extract permissions from source settings.json
    SOURCE_PERMISSIONS=$(jq '.permissions' "${SCRIPT_DIR}/settings.json")

    if [ -f "${TARGET_DIR}/settings.json" ]; then
        # Merge permissions into existing settings.json
        jq --argjson perms "$SOURCE_PERMISSIONS" '.permissions = $perms' \
            "${TARGET_DIR}/settings.json" > "${TARGET_DIR}/settings.json.tmp"
        mv "${TARGET_DIR}/settings.json.tmp" "${TARGET_DIR}/settings.json"
    else
        # Create new settings.json with only permissions field
        echo "{}" | jq --argjson perms "$SOURCE_PERMISSIONS" '.permissions = $perms' \
            > "${TARGET_DIR}/settings.json"
    fi
fi

echo ""
echo "Sync completed"
echo "To verify: ls -la ${TARGET_DIR}"
