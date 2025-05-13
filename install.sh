#!/bin/bash

echo "Installing required dependencies for Zellij SSH/SFTP client..."

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$PARENT_DIR/configmap.conf"

# Load configuration variables from configmap.conf (make sure this file exists in the same directory as this script)
eval "$(grep -E '^(SCRIPT_DIR|CONFIG_DIR|CONFIG_FILE|SRC_DIR)=' "$CONFIG_PATH")"

# Create configuration directory if needed
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating configuration directory..."
    mkdir -p "$CONFIG_DIR"
    echo "Directory created: $CONFIG_DIR"
fi

# Function to install on macOS
install_mac() {
    echo "Detected macOS. Installing dependencies using Homebrew..."

    # Check if Homebrew is installed
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for the current session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        else
            echo "Failed to find brew after installation. Please restart your terminal and run this script again."
            exit 1
        fi
    fi

    # Install zellij
    if ! command -v zellij &>/dev/null; then
        echo "Installing zellij..."
        brew install zellij
    else
        echo "zellij is already installed."
    fi

    # Install fzf
    if ! command -v fzf &>/dev/null; then
        echo "Installing fzf..."
        brew install fzf
        # Install shell extensions
        $(brew --prefix)/opt/fzf/install --all
    else
        echo "fzf is already installed."
    fi

    # Install expect
    if ! command -v expect &>/dev/null; then
        echo "Installing expect..."
        brew install expect
    else
        echo "expect is already installed."
    fi

    # Install midnight-commander
    if ! command -v mc &>/dev/null; then
        echo "Installing midnight-commander..."
        brew install midnight-commander
    else
        echo "midnight-commander is already installed."
    fi

    # Install sshpass
    if ! command -v sshpass &>/dev/null; then
        echo "Installing sshpass..."
        brew tap hudochenkov/sshpass
        brew install hudochenkov/sshpass/sshpass
    else
        echo "sshpass is already installed."
    fi
}

# Function to install on Debian/Ubuntu
install_debian() {
    echo "Detected Debian/Ubuntu. Installing dependencies using apt..."

    # Update package lists
    sudo apt update

    # Install dependencies
    sudo apt install -y fzf expect mc sshpass

    # Install zellij (may not be in repositories)
    if ! command -v zellij &>/dev/null; then
        if ! command -v cargo &>/dev/null; then
            echo "Installing Rust toolchain for zellij..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
        echo "Installing zellij using cargo..."
        cargo install --locked zellij
    fi
}

# Function to install on Red Hat/CentOS/Fedora
install_redhat() {
    echo "Detected Red Hat/CentOS/Fedora. Installing dependencies..."

    # Determine package manager (dnf for newer systems, yum for older)
    if command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    else
        PKG_MGR="yum"
    fi

    # Install dependencies
    sudo $PKG_MGR install -y fzf expect mc sshpass

    # Install zellij (may not be in repositories)
    if ! command -v zellij &>/dev/null; then
        if ! command -v cargo &>/dev/null; then
            echo "Installing Rust toolchain for zellij..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
        echo "Installing zellij using cargo..."
        cargo install --locked zellij
    fi
}

# Function to install on Arch Linux
install_arch() {
    echo "Detected Arch Linux. Installing dependencies using pacman..."

    # Install dependencies
    sudo pacman -Sy --needed fzf expect mc sshpass

    # Install zellij from AUR if not available
    if ! command -v zellij &>/dev/null; then
        if command -v yay &>/dev/null; then
            yay -S zellij
        elif command -v paru &>/dev/null; then
            paru -S zellij
        else
            # Fallback to manually installing from AUR or using cargo
            if ! command -v cargo &>/dev/null; then
                sudo pacman -S --needed rust
            fi
            echo "Installing zellij using cargo..."
            cargo install --locked zellij
        fi
    fi
}

# Detect OS and call appropriate install function
case "$(uname -s)" in
Darwin*)
    install_mac
    ;;
Linux*)
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
        debian | ubuntu | linuxmint)
            install_debian
            ;;
        rhel | centos | fedora | rocky | almalinux)
            install_redhat
            ;;
        arch | manjaro)
            install_arch
            ;;
        *)
            echo "Unsupported Linux distribution: $ID"
            echo "Please install the following packages manually:"
            echo "  - zellij (terminal multiplexer)"
            echo "  - fzf (fuzzy finder)"
            echo "  - expect (automation tool)"
            echo "  - mc (Midnight Commander)"
            echo "  - sshpass (non-interactive ssh password auth)"
            exit 1
            ;;
        esac
    else
        echo "Could not determine Linux distribution."
        echo "Please install the required packages manually."
        exit 1
    fi
    ;;
*)
    echo "Unsupported operating system. This script supports macOS and Linux."
    exit 1
    ;;
esac

# Copy source files to the configuration directory
echo "Copying client scripts to configuration directory..."
if [ -d "$SRC_DIR" ]; then
    # Copy all .sh files from src directory
    for script in "$SRC_DIR"/*.sh; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            cp -v "$script" "$CONFIG_DIR/$script_name"
            chmod +x "$CONFIG_DIR/$script_name"
            echo "Copied and made executable: $script_name"
        fi
    done
else
    echo "Source directory not found: $SRC_DIR"
    echo "This could be because the install script is not being run from its original location."
    echo "Please ensure the 'src' directory with the client scripts exists."
    exit 1
fi

# Create a sample config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating sample configuration file..."
    cat >"$CONFIG_FILE" <<EOF
# Server configuration for zssh 
# Format: "name:user:password@host:port?" (port is optional) 

SERVERS=(
    "example-server:username:password@hostname:22"
    # Add more servers below
)
EOF
    echo "Sample configuration file created: $CONFIG_FILE"
    echo "Please edit this file to add your server configurations."
else
    echo "Configuration file already exists: $CONFIG_FILE"
fi

echo ""
echo "Installation complete! You can now use the SSH and SFTP client scripts."
echo "Make sure to update your server configurations in:"
echo "$CONFIG_FILE"
echo ""
echo "To run the SSH client: zellij run $CONFIG_DIR/ssh_client_loader.sh"
echo "To run the SFTP client: zellij run $CONFIG_DIR/sftp_client_loader.sh"
