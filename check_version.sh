#!/bin/bash
set -e

VERSION_FILE="$HANDLER_DIR/.version"

source ./shared_constraint_root.sh
source ./shared_variables.sh

echo "Checking for updates..."

# Get current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    echo "Current version: $CURRENT_VERSION"
else
    echo "Current version: Not installed"
    echo "Run 'sudo bash setup.sh' to install"
    exit 1
fi

# Get remote version (no need to download, just curl it)
REMOTE_VERSION=$(curl -s "$DOWNLOAD_ROOT/.version" 2>/dev/null || echo "")

if [ -z "$REMOTE_VERSION" ]; then
    echo "ERROR: Could not fetch version information from $DOWNLOAD_ROOT/.version"
    exit 1
fi

echo "Available version: $REMOTE_VERSION"
echo ""

# Compare versions
if [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
    echo "✓ You are on the latest version"
    exit 0
else
    echo "→ Update available! Run 'hphandler update' to upgrade"
    exit 0
fi