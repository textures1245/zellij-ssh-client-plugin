#!/bin/bash

# Import server configuration
# CONFIG_DIR="$HOME/.local/bin/zellij/ssh_client"
# CONFIG_FILE="$CONFIG_DIR/ssh_servers.conf"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$PARENT_DIR/configmap.conf"

# Load configuration variables from configmap.conf (make sure this file exists in the same directory as this script)
eval "$(grep -E '^(CONFIG_DIR|CONFIG_FILE|USE_CURRENT_PANE)=' "$CONFIG_PATH")"

source "$CONFIG_FILE"

# Ensure config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating default configuration..."
    exit 0
fi

# Add this function to clean up old sessions
clean_old_sessions() {
    echo "Cleaning up exited sessions..."
    zellij list-sessions | grep "EXITED" | awk '{print $1}' | xargs -I{} zellij kill-session {}
    echo "Done!"
}

# Clean sessions if argument is passed
if [ "$1" = "clean" ]; then
    clean_old_sessions
    exit 0
fi

# Check if running in Zellij
if [ -z "$ZELLIJ" ]; then
    echo "This script should be run inside a Zellij session."
    exit 1
fi

# Use current pane or not (0 = new tab, 1 = current pane)
# USE_CURRENT_PANE=1

# Select server using fzf
selected=$(printf "%s\n" "${SERVERS[@]}" | cut -d':' -f1 | fzf)

if [ -n "$selected" ]; then
    # Get server details
    for server in "${SERVERS[@]}"; do
        name=$(echo "$server" | cut -d':' -f1)
        if [ "$name" = "$selected" ]; then
            # Extract connection details
            # Format: hostname:username:password@host:port
            username=$(echo "$server" | cut -d':' -f2)
            password=$(echo "$server" | cut -d':' -f3 | cut -d'@' -f1)
            host_part=$(echo "$server" | cut -d'@' -f2)

            # Format for midnight commander: sftp://username:password@host:port/

            # Check if port is specified
            if [[ "$host_part" =~ .*:.* ]]; then
                host="${host_part%:*}"
                port="${host_part##*:}"

                echo "Connecting to $name ($username@$host on port $port)..."
                mc_url="sftp://$username:$password@$host:$port/"

                if [ "$USE_CURRENT_PANE" -eq 1 ]; then
                    # Use current pane with mc
                    mc "$mc_url"
                else
                    # Create a new tab with appropriate name
                    zellij action new-tab --name "$name"
                    sleep 0.2
                    zellij action write-chars "mc \"$mc_url\"\n"
                fi
            else
                # No port specified, use default
                host="$host_part"
                echo "Connecting to $name ($username@$host)..."
                mc_url="sftp://$username:$password@$host/"

                if [ "$USE_CURRENT_PANE" -eq 1 ]; then
                    # Use current pane with mc
                    mc "$mc_url"
                else
                    # Create a new tab with appropriate name
                    zellij action new-tab --name "$name"
                    sleep 0.2
                    zellij action write-chars "mc \"$mc_url\"\n"
                fi
            fi
            break
        fi
    done
fi
