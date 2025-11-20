#!/bin/bash
set -e

# Configuration
DOWNLOAD_ROOT="https://raw.githubusercontent.com/mshimshon/haproxy-handler/refs/heads/main"
BIN_WRAPPER="/usr/local/bin/hphandler"


wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" -q -O "./shared_variables.sh" "$DOWNLOAD_ROOT/shared_variables.sh?nocache=$(date +%s%N)"
wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" -q -O "./shared_constraint_root.sh" "$DOWNLOAD_ROOT/shared_constraint_root.sh?nocache=$(date +%s%N)"
source "./shared_variables.sh"
source "./shared_constraint_root.sh"



VERSION_FILE="$HANDLER_DIR/.version"
# Script names
ADD_ALIAS_SCRIPT="exec_add_alias.sh"
REMOVE_ALIAS_SCRIPT="exec_remove_alias.sh"
INSTALL_BACKEND_SCRIPT="exec_install_backend.sh"
UNINSTALL_BACKEND_SCRIPT="exec_uninstall_backend.sh"
MERGE_MAPPING_SCRIPT="exec_merge_maps.sh"
UPDATE_SCRIPT="update.sh"
CHECK_VERSION_SCRIPT="check_version.sh"

# Fetch version from repository
echo "Fetching version information..."
VERSION=$(curl -H "Cache-Control: no-cache" -H "Pragma: no-cache" -s "$DOWNLOAD_ROOT/.version?nocache=$(date +%s%N)" 2>/dev/null || echo "")

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not fetch version from $DOWNLOAD_ROOT/.version"
    exit 1
fi

echo "=========================================="
echo "HAProxy Handler Setup v$VERSION"
echo "=========================================="


# Check current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    echo "Current version: $CURRENT_VERSION"
    echo "Installing version: $VERSION"
    
    if [ "$CURRENT_VERSION" = "$VERSION" ]; then
        echo "Already on version $VERSION"
        read -p "Reinstall anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
else
    echo "Installing version: $VERSION"
fi

# Create handler directory if not exists
if [ ! -d "$HANDLER_DIR" ]; then
    echo "Creating handler directory..."
    mkdir -p "$HANDLER_DIR"
    chmod 755 "$HANDLER_DIR"
else
    echo "Handler directory exists: $HANDLER_DIR"
fi

# Change to handler directory for downloads
wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" -q -O "$HANDLER_DIR/shared_constraint_root.sh" "$DOWNLOAD_ROOT/shared_constraint_root.sh?nocache=$(date +%s%N)"
wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" -q -O "$HANDLER_DIR/shared_variables.sh" "$DOWNLOAD_ROOT/shared_variables.sh?nocache=$(date +%s%N)"
rm "./shared_variables.sh"
rm "./shared_constraint_root.sh"
cd "$HANDLER_DIR"

# Download scripts
echo "Downloading scripts from $DOWNLOAD_ROOT..."

ALL_SCRIPTS=(
    "$ADD_ALIAS_SCRIPT"
    "$REMOVE_ALIAS_SCRIPT"
    "$INSTALL_BACKEND_SCRIPT"
    "$UNINSTALL_BACKEND_SCRIPT"
    "$MERGE_MAPPING_SCRIPT"
    "$UPDATE_SCRIPT"
    "$CHECK_VERSION_SCRIPT"
)

for script in "${ALL_SCRIPTS[@]}"; do
    echo "  - Downloading $script..."
    wget --no-cache --header="Cache-Control: no-cache" --header="Pragma: no-cache" -q -O "$script" "$DOWNLOAD_ROOT/$script" || {
        echo "ERROR: Failed to download $DOWNLOAD_ROOT/$script"
        exit 1
    }
    chmod +x "$script"
done

echo "Scripts downloaded successfully."

# Create wrapper script
echo "Creating wrapper command..."
cat > "$BIN_WRAPPER" <<EOF
#!/bin/bash

HANDLER_DIR="$HANDLER_DIR"
VERSION_FILE="\$HANDLER_DIR/.version"

# Map friendly names to script files
declare -A SCRIPT_MAP=(
    ["add-alias"]="exec_add_alias.sh"
    ["remove-alias"]="exec_remove_alias.sh"
    ["install"]="exec_install_backend.sh"
    ["uninstall"]="exec_uninstall_backend.sh"
    ["merge-maps"]="exec_merge_maps.sh"
    ["upgrade"]="update.sh"
    ["update"]="check_version.sh"
)

# Handle version command
if [ "\$1" = "version" ] || [ "\$1" = "--version" ] || [ "\$1" = "-v" ]; then
    if [ -f "\$VERSION_FILE" ]; then
        echo "HAProxy Handler v\$(cat \$VERSION_FILE)"
    else
        echo "HAProxy Handler (version unknown)"
    fi
    exit 0
fi

# Show usage if no arguments
if [ \$# -eq 0 ]; then
    cat << USAGE
HAProxy Handler - Manage HAProxy backends and domains

Usage: hphandler <command> [arguments]

Commands:
  install <backend_group> <hostname> <backend_name> <servers_json>
      Install a new backend with domain mapping
      Example: hphandler install "n8n_backend" "n8n.fiscorax.com" "n8n_server" '[["10.0.2.107", "5678", "check"]]'

  uninstall <hostname>
      Uninstall backend by hostname
      Example: hphandler uninstall "n8n.fiscorax.com"

  add-alias <new_hostname> <existing_hostname>
      Add domain alias to existing backend
      Example: hphandler add-alias "n8n-test.fiscorax.com" "n8n.fiscorax.com"

  remove-alias <hostname>
      Remove domain alias (keeps backend if other domains exist)
      Example: hphandler remove-alias "n8n-test.fiscorax.com"

  merge-maps
      Manually trigger domain map merge and reload
      Example: hphandler merge-maps

  version
      Show installed version
      Example: hphandler version

  update
      Check for available updates
      Example: hphandler update

  upgrade
      Check for and install updates
      Example: hphandler upgrade

USAGE
    exit 0
fi

COMMAND=\$1
shift

# Map command to script
if [ -z "\${SCRIPT_MAP[\$COMMAND]}" ]; then
    echo "ERROR: Unknown command '\$COMMAND'"
    echo "Run 'hphandler' without arguments to see usage"
    exit 1
fi

SCRIPT_FILE="\${SCRIPT_MAP[\$COMMAND]}"
SCRIPT_PATH="\$HANDLER_DIR/\$SCRIPT_FILE"

# Check if script exists
if [ ! -f "\$SCRIPT_PATH" ]; then
    echo "ERROR: Script not found: \$SCRIPT_PATH"
    echo "Please reinstall with: sudo bash setup.sh"
    exit 1
fi

# Execute the script with sudo if not root (for commands that need it)
if [ "\$COMMAND" = "update" ] || [ "\$COMMAND" = "install" ] || [ "\$COMMAND" = "uninstall" ] || [ "\$COMMAND" = "add-alias" ] || [ "\$COMMAND" = "remove-alias" ] || [ "\$COMMAND" = "merge-maps" ]; then
    if [ "\$EUID" -ne 0 ]; then
        exec sudo "\$SCRIPT_PATH" "\$@"
    else
        exec "\$SCRIPT_PATH" "\$@"
    fi
else
    exec "\$SCRIPT_PATH" "\$@"
fi
EOF

chmod +x "$BIN_WRAPPER"
echo "Wrapper installed at $BIN_WRAPPER"

# Create required directories if not exist
if [ ! -d "/etc/haproxy/servers" ]; then
    echo "Creating /etc/haproxy/servers..."
    mkdir -p /etc/haproxy/servers
else
    echo "Directory exists: /etc/haproxy/servers"
fi

if [ ! -d "/etc/haproxy/domains" ]; then
    echo "Creating /etc/haproxy/domains..."
    mkdir -p /etc/haproxy/domains
else
    echo "Directory exists: /etc/haproxy/domains"
fi

# Save version
echo "$VERSION" > "$VERSION_FILE"
echo "Version $VERSION installed successfully."

echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Installed version: $VERSION"
echo ""
echo "Usage examples:"
echo "  hphandler --version"
echo "  hphandler update"
echo "  hphandler upgrade"
echo "  hphandler install \"n8n_backend\" \"n8n.fiscorax.com\" \"n8n_server\" '[[\"10.0.2.107\", \"5678\", \"check\"]]'"
echo "  hphandler add-alias \"n8n-test.fiscorax.com\" \"n8n.fiscorax.com\""
echo "  hphandler remove-alias \"n8n-test.fiscorax.com\""
echo "  hphandler uninstall \"n8n.fiscorax.com\""
echo "  hphandler merge-maps"
echo ""
echo "Run 'hphandler' to see full help"
echo ""
echo "To update in the future, run: hphandler update"