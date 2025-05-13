# Zellij SSH/SFTP Client Plugin

A powerful terminal-based SSH and SFTP client leveraging Zellij terminal multiplexer with password authentication, fuzzy server selection, and automatic root elevation.

![SSH/SFTP Client Plugin Interface](https://files.catbox.moe/5ve4su.png)

## Features

- **Simple Server Configuration**: Store server details in a single configuration file
- **Server Selection**: Quickly find and connect to servers using fzf
- **Password Authentication**: Uses sshpass for non-interactive authentication
- **Automatic Root Elevation**: Option to automatically sudo su - after connecting
- **SFTP Support**: File transfers with Midnight Commander interface
- **Tab Support**: Open connections in new Zellij tabs or current pane

## Requirements

The installation script will automatically install these dependencies:

- Zellij - Terminal workspace/multiplexer
- fzf - Fuzzy finder
- expect - Automation tool
- sshpass - Non-interactive SSH password authentication
- mc - Midnight Commander file manager

# OS Support

| OS                 | Implemented | Stable      |
| ------------------ | ----------- | ----------- |
| macOS              | ✅ Yes      | ✅ Stable   |
| Debian/Ubuntu      | ✅ Yes      | 🧪 Testing  |
| RHEL/CentOS/Fedora | ✅ Yes      | 🧪 Testing  |
| Arch Linux         | ✅ Yes      | 🧪 Testing  |

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/zellij-ssh-client-plugin.git
cd zellij-ssh-client-plugin
```

2. Run the installation script:

```bash
chmod +x install.sh
./install.sh
```

The script will detect your OS and install all required dependencies using the appropriate package manager.

## Configuration

### Server Configuration

Edit the `ssh_servers.conf` file to add your server details:

```bash
# Server configuration file
# Format: "name:user:password@host:port?" (port is optional)

SERVERS=(
    "server-name:username:password@hostname:22"
    "another-server:username:password@192.168.1.10"
    "custom-port:username:password@example.com:2222"
)
```

### Client Settings

Edit the `configmap.conf` file to customize behavior:

```bash
# Use current pane or not (0 = new tab, 1 = current pane)
USE_CURRENT_PANE=1

# use sudo (root access) after SSH login (0 = no root access, 1 = root access)
ROOT_ACCESS=1
```

## Usage

### SSH Client

1. Start a Zellij session if not already in one:

```bash
zellij
```

2. Run the SSH client:

```bash
zellij run {YOUR_CONFIG_DIR/src/ssh_client_loader.sh}

## or you can key-bind zellij for execute script through `$HOME/.config/zellij/config.kdl` (default key-bind config location)
    normal {
        # ...
        bind "Ctrl l" { Run "bash" "-c" "~/.local/bin/zellij/ssh-client/src/ssh_client_loader.sh"; }
    }
```

### SFTP Client

1. Within a Zellij session, run the SFTP client:

```bash
zellij run {YOUR_CONFIG_DIR/src/sftp_client_loader.sh}

## or you can key-bind zellij for execute script through `$HOME/.config/zellij/config.kdl` (default key-bind config location)
    normal {
        # ...
        bind "Ctrl ;" { Run "bash" "-c" "~/.local/bin/zellij/ssh-client/src/sftp_client_loader.sh"; }
    }
```

### Cleaning Up Exited Sessions

```bash
zellij run {YOUR_CONFIG_DIR/src/ssh_client_loader.sh} clean
```

## Limitations

- **Authentication Method**: Currently supports only username-password authentication. Key-based authentication and other SSH authentication methods are not yet implemented.
- **Connection Parameters**: Limited to basic connection parameters only (server hostname, username, password, IP address, and port). Advanced SSH options are not supported.

## Security Considerations

**Warning**: This tool stores passwords in plaintext in configuration files. Use only in trusted environments or personal machines.

## Troubleshooting

### Common Issues

- **"realpath: command not found"**
  - Install coreutils: `brew install coreutils` (macOS) or `apt install coreutils` (Debian/Ubuntu)
- **Connection fails with "Host key verification failed"**
  - Connect manually first: `ssh username@hostname` and accept the host key
- **"Cannot open display" with mc**
  - Ensure your terminal supports the required UI elements

## License

This project is licensed under the MIT License
