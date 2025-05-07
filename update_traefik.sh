#!/bin/bash

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if required commands exist
for cmd in traefik wget jq systemctl; do
    if ! command_exists "$cmd"; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

# Get current Traefik version
current_version=$(traefik version | grep "Version:" | awk '{print $2}')
if [ -z "$current_version" ]; then
    echo "Error: Could not determine current Traefik version"
    exit 1
fi

# Validate version format (x.y.z)
if ! [[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format '$current_version'. Expected format: x.y.z"
    exit 1
fi

# Get latest version from GitHub
github_version=$(wget -qO- https://api.github.com/repos/traefik/traefik/releases/latest | jq -r .tag_name)
if [ -z "$github_version" ]; then
    echo "Error: Could not fetch latest version from GitHub"
    exit 1
fi

# Remove 'v' prefix from GitHub version for comparison
github_version_clean=${github_version#v}

# Validate GitHub version format (x.y.z)
if ! [[ "$github_version_clean" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid GitHub version format '$github_version_clean'. Expected format: x.y.z"
    exit 1
fi

echo "Current Traefik version: $current_version"
echo "Latest GitHub version:   $github_version_clean"

# Compare versions
if [ "$current_version" = "$github_version_clean" ]; then
    echo "You have the latest version of Traefik installed."
    exit 0
fi

# If GitHub version is newer
echo "A newer version of Traefik is available."
read -p "Do you want to update Traefik to $github_version? (y/N): " response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 0
fi

# Create directory if it doesn't exist
mkdir -p /root/traefikBinary
cd /root/traefikBinary || exit 1

# Download new version
echo "Downloading Traefik $github_version..."
wget "https://github.com/traefik/traefik/releases/download/$github_version/traefik_${github_version}_linux_amd64.tar.gz"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download Traefik"
    exit 1
fi

# Extract archive
echo "Extracting Traefik binary..."
tar xzvf "traefik_${github_version}_linux_amd64.tar.gz" --one-top-level

# Stop Traefik service before replacing binary
echo "Stopping Traefik service..."
if ! systemctl stop traefik.service; then
    echo "Error: Failed to stop Traefik service"
    rm -rf /root/traefikBinary/*
    exit 1
fi

# Copy binary and set permissions
echo "Installing new Traefik binary..."
if cp traefik/traefik /usr/local/bin/traefik; then
    chown root:root /usr/local/bin/traefik
    chmod 755 /usr/local/bin/traefik
else
    echo "Error: Failed to install new Traefik binary"
    systemctl start traefik.service
    rm -rf /root/traefikBinary/*
    exit 1
fi

# Start Traefik service
echo "Starting Traefik service..."
if ! systemctl start traefik.service; then
    echo "Error: Failed to start Traefik service"
    exit 1
fi

# Check if Traefik is running
echo "Checking Traefik status..."
if systemctl is-active --quiet traefik.service; then
    echo "Traefik has been successfully updated and is running"
    traefik version
else
    echo "Error: Traefik service is not running after update"
    exit 1
fi

# Cleanup
rm -rf /root/traefikBinary/*
