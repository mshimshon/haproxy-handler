#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_constraint_root.sh" || exit 1
source "$SCRIPT_DIR/shared_variables.sh"

# Check if jq is installed, if not install it
if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing jq..."
    apt-get update -qq
    apt-get install -y jq
    echo "jq installed successfully."
fi

# bash script.sh "n8n_backend" "n8n.fiscorax.com" "n8n_server" '[["10.0.0.1", "5678", "check"]]'

# Validate arguments
if [ $# -ne 4 ]; then
    echo "ERROR: Invalid number of arguments"
    echo "Usage: $0 <backend_group> <hostname> <backend_name> <servers_json>"
    echo "Example: $0 \"n8n_backend\" \"n8n.fiscorax.com\" \"n8n_server\" '[[\"10.0.0.1\", \"5678\", \"check\"]]'"
    exit 1
fi

BACKEND_GROUP=$1
HOSTNAME=$2
BACKEND_NAME=$3
SERVERS=$4

# Validate BACKEND_GROUP
if [ -z "$BACKEND_GROUP" ]; then
    echo "ERROR: Backend group cannot be empty"
    exit 1
fi

# Validate HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo "ERROR: Hostname cannot be empty"
    exit 1
fi

# Basic hostname format validation
if ! [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    echo "ERROR: Invalid hostname format: $HOSTNAME"
    exit 1
fi

# Validate BACKEND_NAME
if [ -z "$BACKEND_NAME" ]; then
    echo "ERROR: Backend name cannot be empty"
    exit 1
fi

# Validate SERVERS JSON format
if [ -z "$SERVERS" ]; then
    echo "ERROR: Servers array cannot be empty"
    exit 1
fi

if ! echo "$SERVERS" | jq empty 2>/dev/null; then
    echo "ERROR: Invalid JSON format for servers array"
    echo "Expected format: '[[\"IP\", \"PORT\", \"OPTIONS\"], [\"IP\", \"PORT\", \"OPTIONS\"]]'"
    exit 1
fi

# Validate servers array has at least one valid entry
SERVER_COUNT=$(echo "$SERVERS" | jq 'length')
if [ "$SERVER_COUNT" -eq 0 ]; then
    echo "ERROR: Servers array must contain at least one server"
    exit 1
fi

# Validate each server entry has IP and PORT
VALID_SERVERS=0
for ((i=0; i<SERVER_COUNT; i++)); do
    IP=$(echo "$SERVERS" | jq -r ".[$i][0]")
    PORT=$(echo "$SERVERS" | jq -r ".[$i][1]")
    
    if [ "$IP" != "null" ] && [ "$PORT" != "null" ] && [ -n "$IP" ] && [ -n "$PORT" ]; then
        # Basic IP validation (IPv4)
        if [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Basic port validation
            if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
                VALID_SERVERS=$((VALID_SERVERS + 1))
            else
                echo "WARNING: Invalid port '$PORT' for server $i"
            fi
        else
            echo "WARNING: Invalid IP '$IP' for server $i"
        fi
    fi
done

if [ "$VALID_SERVERS" -eq 0 ]; then
    echo "ERROR: No valid servers found in the array"
    echo "Each server must have a valid IP address and port (1-65535)"
    exit 1
fi


BACKEND_CFG="${SERVERS_DIR}/${BACKEND_GROUP}.cfg"
DOMAIN_MAP="${DOMAINS_DIR}/${BACKEND_GROUP}.map"

# Create directories if they don't exist
mkdir -p "$SERVERS_DIR"
mkdir -p "$DOMAINS_DIR"

echo "=========================================="
echo "Configuring HAProxy Backend"
echo "=========================================="
echo "Backend Group: $BACKEND_GROUP"
echo "Hostname: $HOSTNAME"
echo "Backend Name: $BACKEND_NAME"
echo "Valid Servers: $VALID_SERVERS"
echo "Server Config: $BACKEND_CFG"
echo "Domain Map: $DOMAIN_MAP"
echo "=========================================="

# 1. Check if hostname already exists in ANY domain map
if grep -r "^${HOSTNAME} " "$DOMAINS_DIR"/*.map 2>/dev/null; then
    echo "ERROR: Hostname '$HOSTNAME' already exists in domain maps"
    exit 1
fi

# 2. Build the complete backend configuration
echo "Creating backend configuration file..."

# Start building the backend config string
BACKEND_CONFIG="backend ${BACKEND_GROUP}
    mode http
    timeout tunnel 3600s
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Port 443
    http-request set-header X-Real-IP %[src]"

# Parse servers array and add server lines
for ((i=0; i<SERVER_COUNT; i++)); do
    IP=$(echo "$SERVERS" | jq -r ".[$i][0]")
    PORT=$(echo "$SERVERS" | jq -r ".[$i][1]")
    OPTIONS=$(echo "$SERVERS" | jq -r ".[$i][2] // \"check\"")
    
    # Skip empty or invalid entries
    if [ -z "$IP" ] || [ -z "$PORT" ] || [ "$IP" = "null" ] || [ "$PORT" = "null" ]; then
        continue
    fi
    
    # Validate IP format
    if ! [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        continue
    fi
    
    # Validate port range
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        continue
    fi
    
    SERVER_NAME="${BACKEND_NAME}_${i}"
    BACKEND_CONFIG="${BACKEND_CONFIG}
    server ${SERVER_NAME} ${IP}:${PORT} ${OPTIONS}"
    echo "Added server: ${SERVER_NAME} -> ${IP}:${PORT} ${OPTIONS}"
done

# Write backend config to its own file
echo "$BACKEND_CONFIG" > "$BACKEND_CFG"

echo "Backend configuration file created successfully."

# 3. Create domain mapping file
echo "Creating domain mapping file..."
echo "${HOSTNAME} ${BACKEND_GROUP}" > "$DOMAIN_MAP"
echo "Domain mapping file created successfully."

# 4. Merge all domain maps into single file
echo "Merging domain maps..."
bash "$MERGE_SCRIPT_FILE"

# 5. Reload HAProxy
echo "Reloading HAProxy..."
systemctl reload haproxy

echo "=========================================="
echo "Configuration complete!"
echo "Access your service at: https://${HOSTNAME}"
echo "=========================================="

#sudo bash add.sh "n8n_test_backend" "n8n.fiscorax.com" "n8n_test_server" '[["10.0.2.107", "5678", "check"]]'