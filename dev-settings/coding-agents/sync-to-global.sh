#!/usr/bin/env bash

set -euo pipefail

# Get script directory
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TARGET_DIR="${HOME}/.claude"

echo "Claude configuration sync script"
echo "Source: ${SCRIPT_DIR}"
echo "Target: ${TARGET_DIR}"
echo ""

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed. This script requires Python 3."
    exit 1
fi

# Function to calculate checksum using Python (OS-independent)
calculate_checksum() {
    local target=$1
    python3 << EOF
import hashlib
import os
import sys

def hash_file(filepath):
    """Calculate SHA256 hash of a file."""
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                sha256.update(chunk)
        return sha256.hexdigest()
    except FileNotFoundError:
        return "NOT_EXISTS"

def hash_directory(dirpath):
    """Calculate combined hash of all files in a directory."""
    sha256 = hashlib.sha256()
    try:
        for root, dirs, files in sorted(os.walk(dirpath)):
            dirs.sort()
            for filename in sorted(files):
                filepath = os.path.join(root, filename)
                rel_path = os.path.relpath(filepath, dirpath)
                sha256.update(rel_path.encode())
                sha256.update(hash_file(filepath).encode())
        return sha256.hexdigest()
    except FileNotFoundError:
        return "NOT_EXISTS"

target = "${target}"
if os.path.isfile(target):
    print(hash_file(target))
elif os.path.isdir(target):
    print(hash_directory(target))
else:
    print("NOT_EXISTS")
EOF
}

# Calculate checksums before sync
echo "Calculating checksums before sync..."
CLAUDE_MD_BEFORE=$(calculate_checksum "${TARGET_DIR}/CLAUDE.md")
AGENT_DOCS_BEFORE=$(calculate_checksum "${TARGET_DIR}/agent-docs")
SETTINGS_JSON_BEFORE=$(calculate_checksum "${TARGET_DIR}/settings.json")
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
echo ""

# Setup GitHub Copilot CLI symlink
echo "Setting up GitHub Copilot CLI symlink..."
COPILOT_INSTRUCTIONS="${HOME}/.github/copilot-instructions.md"
CLAUDE_MD="${TARGET_DIR}/CLAUDE.md"

# Create .github directory if it does not exist
if [ ! -d "${HOME}/.github" ]; then
    echo "Creating directory: ${HOME}/.github"
    mkdir -p "${HOME}/.github"
fi

# Remove existing file or symlink if it exists
if [ -e "${COPILOT_INSTRUCTIONS}" ] || [ -L "${COPILOT_INSTRUCTIONS}" ]; then
    echo "Removing existing copilot-instructions.md"
    rm -f "${COPILOT_INSTRUCTIONS}"
fi

# Create symlink
echo "Creating symlink: ${COPILOT_INSTRUCTIONS} -> ${CLAUDE_MD}"
ln -s "${CLAUDE_MD}" "${COPILOT_INSTRUCTIONS}"

echo ""

# Calculate checksums after sync
echo "Calculating checksums after sync..."
CLAUDE_MD_AFTER=$(calculate_checksum "${TARGET_DIR}/CLAUDE.md")
AGENT_DOCS_AFTER=$(calculate_checksum "${TARGET_DIR}/agent-docs")
SETTINGS_JSON_AFTER=$(calculate_checksum "${TARGET_DIR}/settings.json")
COPILOT_SYMLINK_STATUS="not_checked"
if [ -L "${HOME}/.github/copilot-instructions.md" ]; then
    COPILOT_SYMLINK_STATUS="exists"
fi
echo ""

# Display changes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Change Detection Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

has_changes=false

if [ "$CLAUDE_MD_BEFORE" != "$CLAUDE_MD_AFTER" ]; then
    echo "  ✓ CLAUDE.md (updated)"
    has_changes=true
else
    echo "  - CLAUDE.md (no changes)"
fi

if [ "$AGENT_DOCS_BEFORE" != "$AGENT_DOCS_AFTER" ]; then
    echo "  ✓ agent-docs/ (updated)"
    has_changes=true
else
    echo "  - agent-docs/ (no changes)"
fi

if [ -f "${SCRIPT_DIR}/settings.json" ]; then
    if [ "$SETTINGS_JSON_BEFORE" != "$SETTINGS_JSON_AFTER" ]; then
        echo "  ✓ settings.json (updated)"
        has_changes=true
    else
        echo "  - settings.json (no changes)"
    fi
fi

if [ "$COPILOT_SYMLINK_STATUS" = "exists" ]; then
    echo "  ✓ GitHub Copilot symlink (created)"
    has_changes=true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$has_changes" = true ]; then
    echo "✓ Changes were applied successfully"
else
    echo "✓ All files were already up to date"
fi
