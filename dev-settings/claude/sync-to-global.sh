#!/usr/bin/env bash

set -euo pipefail

# Get script directory
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TARGET_DIR="${HOME}/.claude"

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

    # Check if python3 is available
    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 is not installed. Please install Python 3 to sync permissions."
        exit 1
    fi

    # Merge permissions into target settings.json using Python
    python3 << 'EOF'
import json
import sys
import os

script_dir = os.environ['SCRIPT_DIR']
target_dir = os.environ['TARGET_DIR']

# Read source permissions
with open(f"{script_dir}/settings.json", 'r') as f:
    source = json.load(f)
    source_permissions = source.get('permissions', {})

# Read or create target settings
target_file = f"{target_dir}/settings.json"
if os.path.exists(target_file):
    with open(target_file, 'r') as f:
        target = json.load(f)
else:
    target = {}

# Merge permissions
target['permissions'] = source_permissions

# Write back
with open(target_file, 'w') as f:
    json.dump(target, f, indent=2)
    f.write('\n')
EOF
fi

echo ""
echo "Sync completed"
echo "To verify: ls -la ${TARGET_DIR}"
