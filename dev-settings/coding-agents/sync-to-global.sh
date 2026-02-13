#!/usr/bin/env bash

set -euo pipefail

# Get script directory
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CENTRAL_DIR="${HOME}/.connect0459/coding-agents"
export CLAUDE_TARGET_DIR="${HOME}/.claude"

echo "Coding agents configuration sync script"
echo "Source: ${SCRIPT_DIR}"
echo "Central: ${CENTRAL_DIR}"
echo "Claude Target: ${CLAUDE_TARGET_DIR}"
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
AGENTS_MD_BEFORE=$(calculate_checksum "${CENTRAL_DIR}/AGENTS.md")
AGENT_DOCS_BEFORE=$(calculate_checksum "${CENTRAL_DIR}/agent-docs")
CLAUDE_SETTINGS_JSON_BEFORE=$(calculate_checksum "${CLAUDE_TARGET_DIR}/settings.json")
echo ""

# Create central directory if it does not exist
if [ ! -d "${CENTRAL_DIR}" ]; then
    echo "Creating central directory: ${CENTRAL_DIR}"
    mkdir -p "${CENTRAL_DIR}"
fi

# Create agent-docs directory in central location
if [ ! -d "${CENTRAL_DIR}/agent-docs" ]; then
    echo "Creating central agent-docs directory"
    mkdir -p "${CENTRAL_DIR}/agent-docs"
fi

# Create Claude target directory if it does not exist
if [ ! -d "${CLAUDE_TARGET_DIR}" ]; then
    echo "Creating Claude target directory: ${CLAUDE_TARGET_DIR}"
    mkdir -p "${CLAUDE_TARGET_DIR}"
fi

# Sync AGENTS.md to central location (physical copy)
echo "Syncing AGENTS.md to central location"
cp "${SCRIPT_DIR}/AGENTS.md" "${CENTRAL_DIR}/AGENTS.md"

# Sync agent-docs directory to central location (delete files not in source)
echo "Syncing agent-docs directory to central location"
rsync -a --delete "${SCRIPT_DIR}/agent-docs/" "${CENTRAL_DIR}/agent-docs/"

# Sync permissions field from settings.json
if [ -f "${SCRIPT_DIR}/claude/settings.json" ]; then
    echo "Syncing permissions from settings.json"

    # Merge permissions into target settings.json using Python
    python3 << 'EOF'
import json
import sys
import os

script_dir = os.environ['SCRIPT_DIR']
claude_target_dir = os.environ['CLAUDE_TARGET_DIR']

# Read source permissions
with open(f"{script_dir}/claude/settings.json", 'r') as f:
    source = json.load(f)
    source_permissions = source.get('permissions', {})

# Read or create target settings
target_file = f"{claude_target_dir}/settings.json"
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

# Setup symlinks
echo "Setting up symlinks..."
CENTRAL_AGENTS_MD="${CENTRAL_DIR}/AGENTS.md"
CLAUDE_MD="${CLAUDE_TARGET_DIR}/CLAUDE.md"
COPILOT_INSTRUCTIONS="${HOME}/.github/copilot-instructions.md"

# Create .github directory if it does not exist
if [ ! -d "${HOME}/.github" ]; then
    echo "Creating directory: ${HOME}/.github"
    mkdir -p "${HOME}/.github"
fi

# Setup Claude CLAUDE.md symlink to central AGENTS.md
if [ -e "${CLAUDE_MD}" ] || [ -L "${CLAUDE_MD}" ]; then
    echo "Removing existing ${CLAUDE_MD}"
    rm -f "${CLAUDE_MD}"
fi
echo "Creating symlink: ${CLAUDE_MD} -> ${CENTRAL_AGENTS_MD}"
ln -s "${CENTRAL_AGENTS_MD}" "${CLAUDE_MD}"

# Setup GitHub Copilot instructions symlink to central AGENTS.md
if [ -e "${COPILOT_INSTRUCTIONS}" ] || [ -L "${COPILOT_INSTRUCTIONS}" ]; then
    echo "Removing existing ${COPILOT_INSTRUCTIONS}"
    rm -f "${COPILOT_INSTRUCTIONS}"
fi
echo "Creating symlink: ${COPILOT_INSTRUCTIONS} -> ${CENTRAL_AGENTS_MD}"
ln -s "${CENTRAL_AGENTS_MD}" "${COPILOT_INSTRUCTIONS}"

echo ""

# Calculate checksums after sync
echo "Calculating checksums after sync..."
AGENTS_MD_AFTER=$(calculate_checksum "${CENTRAL_DIR}/AGENTS.md")
AGENT_DOCS_AFTER=$(calculate_checksum "${CENTRAL_DIR}/agent-docs")
CLAUDE_SETTINGS_JSON_AFTER=$(calculate_checksum "${CLAUDE_TARGET_DIR}/settings.json")
CLAUDE_SYMLINK_STATUS="not_checked"
COPILOT_SYMLINK_STATUS="not_checked"
if [ -L "${CLAUDE_TARGET_DIR}/CLAUDE.md" ]; then
    CLAUDE_SYMLINK_STATUS="exists"
fi
if [ -L "${HOME}/.github/copilot-instructions.md" ]; then
    COPILOT_SYMLINK_STATUS="exists"
fi
echo ""

# Display changes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Change Detection Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

has_changes=false

if [ "$AGENTS_MD_BEFORE" != "$AGENTS_MD_AFTER" ]; then
    echo "  ✓ AGENTS.md (updated)"
    has_changes=true
else
    echo "  - AGENTS.md (no changes)"
fi

if [ "$AGENT_DOCS_BEFORE" != "$AGENT_DOCS_AFTER" ]; then
    echo "  ✓ agent-docs/ (updated)"
    has_changes=true
else
    echo "  - agent-docs/ (no changes)"
fi

if [ -f "${SCRIPT_DIR}/claude/settings.json" ]; then
    if [ "$CLAUDE_SETTINGS_JSON_BEFORE" != "$CLAUDE_SETTINGS_JSON_AFTER" ]; then
        echo "  ✓ settings.json (updated)"
        has_changes=true
    else
        echo "  - settings.json (no changes)"
    fi
fi

if [ "$CLAUDE_SYMLINK_STATUS" = "exists" ]; then
    echo "  ✓ Claude symlink (created)"
    has_changes=true
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
