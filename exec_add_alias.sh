#!/bin/bash
set -e
source ./shared_constraint_root.sh
source ./shared_variables.sh

# bash add_alias.sh "n8n-staging.fiscorax.com" "n8n.fiscorax.com"

if [ $# -ne 2 ]; then
    echo "ERROR: Invalid number of arguments"
    echo "Usage: $0 <new_hostname> <existing_hostname>"
    echo "Example: $0 \"n8n-staging.fiscorax.com\" \"n8n.fiscorax.com\""
    exit 1
fi

NEW_HOSTNAME=$1
EXISTING_HOSTNAME=$2



# Validate NEW_HOSTNAME format
if ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    echo "ERROR: Invalid hostname format: $NEW_HOSTNAME"
    exit 1
fi

# Validate EXISTING_HOSTNAME format
if ! [[ "$EXISTING_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    echo "ERROR: Invalid hostname format: $EXISTING_HOSTNAME"
    exit 1
fi

echo "=========================================="
echo "Adding Hostname Alias"
echo "=========================================="
echo "New Hostname: $NEW_HOSTNAME"
echo "Existing Hostname: $EXISTING_HOSTNAME"

# 1. Find the target backend (from existing hostname)
TARGET_BACKEND=""
TARGET_MAP_FILE=""

for mapfile in "$DOMAINS_DIR"/*.map; do
    if [ -f "$mapfile" ] && grep -q "^${EXISTING_HOSTNAME} " "$mapfile"; then
        TARGET_BACKEND=$(grep "^${EXISTING_HOSTNAME} " "$mapfile" | awk '{print $2}')
        TARGET_MAP_FILE="$mapfile"
        break
    fi
done

if [ -z "$TARGET_BACKEND" ]; then
    echo "ERROR: Existing hostname '$EXISTING_HOSTNAME' not found in any domain map"
    exit 1
fi

echo "Target Backend: $TARGET_BACKEND"
echo "Target Map File: $TARGET_MAP_FILE"

# 2. Check if new hostname already exists anywhere
NEW_HOSTNAME_BACKEND=""
NEW_HOSTNAME_MAP_FILE=""

for mapfile in "$DOMAINS_DIR"/*.map; do
    if [ -f "$mapfile" ] && grep -q "^${NEW_HOSTNAME} " "$mapfile"; then
        NEW_HOSTNAME_BACKEND=$(grep "^${NEW_HOSTNAME} " "$mapfile" | awk '{print $2}')
        NEW_HOSTNAME_MAP_FILE="$mapfile"
        break
    fi
done

# 3. If new hostname exists, check if it points to the same backend
if [ -n "$NEW_HOSTNAME_BACKEND" ]; then
    if [ "$NEW_HOSTNAME_BACKEND" == "$TARGET_BACKEND" ]; then
        echo "Hostname '$NEW_HOSTNAME' already points to backend '$TARGET_BACKEND'"
        echo "No changes needed."
        echo "=========================================="
        echo "Alias already configured!"
        echo "Access your service at: https://${NEW_HOSTNAME}"
        echo "=========================================="
        exit 0
    else
        echo "ERROR: Hostname '$NEW_HOSTNAME' already exists pointing to backend '$NEW_HOSTNAME_BACKEND'"
        echo "Cannot repoint to '$TARGET_BACKEND'"
        exit 1
    fi
fi

# 4. Add new hostname to the target map file
echo "Adding alias to map file..."
echo "${NEW_HOSTNAME} ${TARGET_BACKEND}" >> "$TARGET_MAP_FILE"
echo "Alias added successfully."

echo "Merging domain maps..."
bash "$MERGE_SCRIPT_FILE"

# 6. Reload HAProxy
echo "Reloading HAProxy..."
systemctl reload haproxy

echo "=========================================="
echo "Alias creation complete!"
echo "Access your service at: https://${NEW_HOSTNAME}"
echo "Both hostnames now point to backend: $TARGET_BACKEND"
echo "=========================================="