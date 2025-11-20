#!/bin/bash
set -e

# Configuration


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_constraint_root.sh"
source "$SCRIPT_DIR/shared_variables.sh"
SETUP_SCRIPT="$HANDLER_DIR/setup.sh"

echo "=========================================="
echo "HAProxy Handler Update"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root or with sudo"
    exit 1
fi

# Show current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    echo "Current version: $CURRENT_VERSION"
else
    echo "Current version: Not installed"
    CURRENT_VERSION=""
fi

# Download latest setup.sh
echo "Downloading latest setup.sh..."
wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" \
    -q -O "$SETUP_SCRIPT" "$DOWNLOAD_ROOT/setup.sh?nocache=$(date +%s%N)"

if [ $? -ne 0 ] || [ ! -s "$SETUP_SCRIPT" ]; then
    echo "ERROR: Failed to download setup.sh"
    exit 1
fi

chmod +x "$SETUP_SCRIPT"
echo "Downloaded setup.sh"

# Fetch remote version
REMOTE_VERSION=$(curl -fsSL "$DOWNLOAD_ROOT/.version?nocache=$(date +%s%N)")
if [ -z "$REMOTE_VERSION" ]; then
    echo "ERROR: Could not fetch version information"
    exit 1
fi

echo "Available version: $REMOTE_VERSION"

# Compare versions
if [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
    echo ""
    echo "You are already on the latest version ($CURRENT_VERSION)"
    echo "No update needed."
    exit 0
fi

# Version is different, run setup
echo ""
echo "New version available: $REMOTE_VERSION"
echo "Running setup.sh..."
echo ""

bash "$SETUP_SCRIPT"

echo ""
echo "=========================================="
echo "Update complete!"
echo "Updated from $CURRENT_VERSION to $REMOTE_VERSION"
echo "=========================================="