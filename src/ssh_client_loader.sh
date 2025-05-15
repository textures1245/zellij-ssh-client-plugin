#!/bin/bash

# Import server configuration
# CONFIG_DIR="$HOME/.local/bin/zellij/ssh_client"
# CONFIG_FILE="$CONFIG_DIR/ssh_servers.conf"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$PARENT_DIR/configmap.conf"

echo "CONFIG_PATH: $CONFIG_PATH"

# Load configuration variables from configmap.conf (make sure this file exists in the same directory as this script)
eval "$(grep -E '^(CONFIG_DIR|CONFIG_FILE|USE_CURRENT_PANE|ROOT_ACCESS)=' "$CONFIG_PATH")"

source "$CONFIG_FILE"

# Ensure config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found."
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

# Check if sshpass is installed
if ! command -v sshpass &>/dev/null; then
    echo "sshpass is required but not installed. Please install it with:"
    echo "brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# Check if expect is installed
if ! command -v expect &>/dev/null; then
    echo "expect is required but not installed. Please install it with:"
    echo "brew install expect"
    exit 1
fi

# Configuration options
# USE_CURRENT_PANE=1
# ROOT_ACCESS=1

# Select server using fzf
selected=$(printf "%s\n" "${SERVERS[@]}" | cut -d':' -f1 | fzf)

if [ -n "$selected" ]; then
    # Get server details
    for server in "${SERVERS[@]}"; do
        name=$(echo "$server" | cut -d':' -f1)
        if [ "$name" = "$selected" ]; then
            # Extract connection details
            username=$(echo "$server" | cut -d':' -f2)
            password=$(echo "$server" | cut -d':' -f3 | cut -d'@' -f1)
            host_part=$(echo "$server" | cut -d'@' -f2)

            # Check if port is specified
            if [[ "$host_part" =~ .*:.* ]]; then
                host="${host_part%:*}"
                port="${host_part##*:}"
                port_option="-p $port"
            else
                host="$host_part"
                port_option=""
            fi

            echo "Connecting to $name ($username@$host)..."

            # Instead of creating a temporary script, we'll use a more direct approach
            if [ "$USE_CURRENT_PANE" -eq 1 ]; then
                if [ "$ROOT_ACCESS" -eq 1 ]; then
                    # Create an expect script to handle the interactive SSH+sudo session
                    EXPECT_SCRIPT=$(mktemp)
                    cat >"$EXPECT_SCRIPT" <<EOF
#!/usr/bin/expect -f
# This script handles both SSH login and sudo elevation with support for passwordless auth
set timeout 30

# Start the SSH connection
spawn ssh $port_option $username@$host

# First handle SSH login with or without password
expect {
    "Password:" { send "$password\r"; exp_continue }
    "password:" { send "$password\r"; exp_continue }
    "yes/no" { send "yes\r"; exp_continue }
    "*\\\$*" { }  # Just continue if we get a shell prompt
    "*>*" { }     # Just continue for Windows/PowerShell prompts
    "*#*" { }     # Already root prompt
    timeout { puts "Timeout waiting for prompt"; exit 1 }
}

# Now try sudo, with flexible prompt handling
send "sudo su -\r"

# Handle sudo - could be passwordless
expect {
    "*assword*" { send "$password\r"; exp_continue }
    "*ASSWD*" { send "$password\r"; exp_continue }
    "*root*" { }  # Already got root prompt
    "*#*" { }     # Already got root prompt
    timeout { }   # Just continue if passwordless sudo
}

# Set the command prompt regardless of how we got here
send "export PS1='\\u@\\h:\\w\\$ '\r"

# Disable timeout before entering interactive mode
set timeout -1

# Now we should be at root prompt, hand control back to user
interact
EOF

                    chmod +x "$EXPECT_SCRIPT"

                    # Run the expect script explicitly with expect
                    expect "$EXPECT_SCRIPT"

                    # Clean up when done
                    rm -f "$EXPECT_SCRIPT"
                else
                    # Just regular SSH connection
                    SSHPASS="$password" sshpass -e ssh $port_option "$username@$host"
                fi
            else
                # Create a new tab with appropriate name
                zellij action new-tab --name "$name"
                sleep 0.2

                if [ "$ROOT_ACCESS" -eq 1 ]; then
                    # In a new tab, we'll use a simpler approach with expect
                    zellij action write-chars "expect -c 'spawn ssh $port_option $username@$host; expect \"*assword*\"; send \"$password\\r\"; expect \"*\\\$*\"; send \"sudo su -\\r\"; expect \"*assword*\"; send \"$password\\r\"; interact'\n"
                else
                    # Just regular SSH connection
                    zellij action write-chars "SSHPASS=\"$password\" sshpass -e ssh $port_option $username@$host\n"
                fi
            fi

            break
        fi
    done
fi
