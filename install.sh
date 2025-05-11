#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: install.sh
# Description: Entry point for Traefik container installation
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-05-10
# Version: v0.1.0
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/peterweissdk/traefik/refs/heads/main/install.sh)"
# ----------------------------------------------------------------------------

set -e

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
if ! command_exists git; then
    echo "Git is required but not installed."
    read -p "Would you like to install Git? (y/N) " answer
    case ${answer:0:1} in
        y|Y )
            echo "Installing Git..."
            apt-get update && apt-get install -y git
            ;;
        * )
            echo "Git is required for installation. Exiting."
            exit 1
            ;;
    esac
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Clone the repository
echo "Cloning Traefik installation files..."
git clone https://github.com/peterweissdk/traefik.git "$TEMP_DIR"

# Make scripts executable
chmod +x "$TEMP_DIR"/install_traefik_container.sh
chmod +x "$TEMP_DIR"/install_traefik.sh
chmod +x "$TEMP_DIR"/setup_traefik.sh

# Run the installation script
echo "Starting Traefik container installation..."
"$TEMP_DIR"/install_traefik_container.sh

# Clean up
rm -rf "$TEMP_DIR"

echo "Installation complete!"
exit 0
