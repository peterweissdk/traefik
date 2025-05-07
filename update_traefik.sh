#!/bin/bash

# Global variables
VERSION=""
LOG_DIR="/var/log/"
LOG_FILE="${LOG_DIR}/update_traefik.log"

# Write to log file
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    # Print to stdout, errors to stderr
    if [ "$level" = "ERROR" ]; then
        echo "[${timestamp}] [${level}] ${message}" >&2
    else
        echo "${message}"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
check_dependencies() {
    for cmd in traefik wget jq systemctl; do
        if ! command_exists "$cmd"; then
            echo "Error: Required command '$cmd' is not installed."
            exit 1
        fi
    done
}

# Get and validate current version
get_current_version() {
    local version
    version=$(traefik version | grep "Version:" | awk '{print $2}')
    if [ -z "$version" ]; then
        echo "Error: Could not determine current Traefik version"
        exit 1
    fi

    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format '$version'. Expected format: x.y.z"
        exit 1
    fi
    echo "$version"
}

# Get and validate latest version from GitHub
get_github_version() {
    local version
    version=$(wget -qO- https://api.github.com/repos/traefik/traefik/releases/latest | jq -r .tag_name)
    if [ -z "$version" ]; then
        echo "Error: Could not fetch latest version from GitHub"
        exit 1
    fi

    # Remove 'v' prefix
    version=${version#v}

    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid GitHub version format '$version'. Expected format: x.y.z"
        exit 1
    fi
    echo "$version"
}

# Download and extract new version
download_traefik() {
    mkdir -p /root/traefikBinary
    cd /root/traefikBinary || exit 1

    echo "Downloading Traefik v$VERSION..."
    if ! wget "https://github.com/traefik/traefik/releases/download/v$VERSION/traefik_v${VERSION}_linux_amd64.tar.gz"; then
        echo "Error: Failed to download Traefik"
        exit 1
    fi

    echo "Extracting Traefik binary..."
    tar xzvf "traefik_v${VERSION}_linux_amd64.tar.gz" --one-top-level
}

# Install new binary
install_binary() {
    echo "Stopping Traefik service..."
    if ! systemctl stop traefik.service; then
        echo "Error: Failed to stop Traefik service"
        cleanup
        exit 1
    fi

    echo "Installing new Traefik binary..."
    if cp traefik/traefik /usr/local/bin/traefik; then
        chown root:root /usr/local/bin/traefik
        chmod 755 /usr/local/bin/traefik
    else
        echo "Error: Failed to install new Traefik binary"
        systemctl start traefik.service
        cleanup
        exit 1
    fi

    echo "Starting Traefik service..."
    if ! systemctl start traefik.service; then
        echo "Error: Failed to start Traefik service"
        exit 1
    fi
}

# Cleanup downloaded files
cleanup() {
    rm -rf /root/traefikBinary/*
}

# Check versions and prompt for update
check_version() {
    local current_version github_version
    current_version=$(get_current_version)
    github_version=$(get_github_version)

    echo "Current Traefik version: $current_version"
    echo "Latest GitHub version:   $github_version"

    if [ "$current_version" = "$github_version" ]; then
        echo "You have the latest version of Traefik installed."
        exit 0
    fi

    echo "A newer version of Traefik is available."
    read -p "Do you want to update Traefik to v$github_version? (y/N): " response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        exit 0
    fi

    VERSION=$github_version
}

# Main function
main() {
    check_dependencies
    check_version
    download_traefik
    install_binary
    cleanup

    echo "Traefik has been successfully updated to v$VERSION"
    traefik version
}

# Execute main function
main
