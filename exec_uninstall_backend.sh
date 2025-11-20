#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_constraint_root.sh" || exit 1
source "$SCRIPT_DIR/shared_variables.sh"

# bash script.sh "n8n.fiscorax.com"
HOSTNAME=$1


echo "=========================================="
echo "Removing HAProxy Backend"
echo "=========================================="
echo "Hostname: $HOSTNAME"

# 1. Find which map file contains this hostname
BACKEND_GROUP=""
MAP_FILE=""

for mapfile in "$DOMAINS_DIR"/*.map; do
    if [ -f "$mapfile" ] && grep -q "^${HOSTNAME} " "$mapfile"; then
        BACKEND_GROUP=$(grep "^${HOSTNAME} " "$mapfile" | awk '{print $2}')
        MAP_FILE="$mapfile"
        break
    fi
done

if [ -z "$BACKEND_GROUP" ]; then
    echo "ERROR: Hostname '$HOSTNAME' not found in any domain map"
    exit 1
fi

BACKEND_CFG="${SERVERS_DIR}/${BACKEND_GROUP}.cfg"

echo "Backend Group: $BACKEND_GROUP"
echo "Map File: $MAP_FILE"
echo "Server Config: $BACKEND_CFG"

# 2. Remove domain map file
if [ -f "$MAP_FILE" ]; then
    echo "Removing domain map file..."
    rm "$MAP_FILE"
    echo "Domain map file removed."
fi

# 3. Remove backend config file
if [ -f "$BACKEND_CFG" ]; then
    echo "Removing backend configuration file..."
    rm "$BACKEND_CFG"
    echo "Backend configuration file removed."
else
    echo "WARNING: Backend config file '$BACKEND_CFG' not found"
fi

echo "Merging domain maps..."
bash "$MERGE_SCRIPT_FILE"

# 5. Reload HAProxy
echo "Reloading HAProxy..."
systemctl reload haproxy

echo "=========================================="
echo "Removal complete!"
echo "Hostname '$HOSTNAME' has been removed."
echo "=========================================="