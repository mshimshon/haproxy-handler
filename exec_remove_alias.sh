#!/bin/bash
set -e
source ./shared_constraint_root.sh
source ./shared_variables.sh
# bash remove_alias.sh "n8n-staging.fiscorax.com"

if [ $# -ne 1 ]; then
    echo "ERROR: Invalid number of arguments"
    echo "Usage: $0 <hostname>"
    echo "Example: $0 \"n8n-staging.fiscorax.com\""
    exit 1
fi

HOSTNAME=$1


# Validate HOSTNAME format
if ! [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    echo "ERROR: Invalid hostname format: $HOSTNAME"
    exit 1
fi

echo "=========================================="
echo "Removing Hostname Alias"
echo "=========================================="
echo "Hostname: $HOSTNAME"

# 1. Find which map file contains this hostname
MAP_FILE=""
BACKEND_GROUP=""

for mapfile in "$DOMAINS_DIR"/*.map; do
    if [ -f "$mapfile" ] && grep -q "^${HOSTNAME} " "$mapfile"; then
        BACKEND_GROUP=$(grep "^${HOSTNAME} " "$mapfile" | awk '{print $2}')
        MAP_FILE="$mapfile"
        break
    fi
done

if [ -z "$MAP_FILE" ]; then
    echo "ERROR: Hostname '$HOSTNAME' not found in any domain map"
    exit 1
fi

echo "Backend Group: $BACKEND_GROUP"
echo "Map File: $MAP_FILE"

# 2. Count how many hostnames are in this map file
LINE_COUNT=$(grep -c "^" "$MAP_FILE")

echo "Hostnames in map file: $LINE_COUNT"

# 3. Check if this is the only hostname
if [ "$LINE_COUNT" -eq 1 ]; then
    echo "ERROR: Cannot remove the only hostname from backend '$BACKEND_GROUP'"
    echo "This backend has only one domain associated with it."
    echo "Use remove.sh to remove the entire backend instead."
    exit 1
fi

# 4. Remove the hostname line from the map file
echo "Removing hostname from map file..."
sed -i "/^${HOSTNAME} /d" "$MAP_FILE"
echo "Hostname removed from map file."

# 5. Merge all domain maps
echo "Merging domain maps..."
bash "$MERGE_SCRIPT_FILE"

# 6. Reload HAProxy
echo "Reloading HAProxy..."
systemctl reload haproxy

echo "=========================================="
echo "Alias removal complete!"
echo "Hostname '$HOSTNAME' has been removed."
echo "Backend '$BACKEND_GROUP' still accessible via other hostnames."
echo "=========================================="