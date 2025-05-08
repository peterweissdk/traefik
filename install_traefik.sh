#!/bin/bash

# Variables
TRAEFIK_VERSION="3.4.0"
DOWNLOAD_DIR=""
INSTALL_DIR="/usr/local/bin"

# Download function
download_traefik() {
    mkdir -p /root/traefikBinary
    cd /root/traefikBinary || exit 1

    echo "Downloading Traefik v$TRAEFIK_VERSION..."
    if ! wget "https://github.com/traefik/traefik/releases/download/v$TRAEFIK_VERSION/traefik_v${TRAEFIK_VERSION}_linux_amd64.tar.gz"; then
        echo "Failed to download Traefik"
        exit 1
    fi

    echo "Extracting Traefik binary..."
    echo "#####Extracted files#####"
    if ! tar xzvf "traefik_v${TRAEFIK_VERSION}_linux_amd64.tar.gz" --one-top-level; then
        echo "Failed to extract Traefik archive"
        exit 1
    fi
    echo "#########################"

    # Set DOWNLOAD_DIR to the extracted directory
    DOWNLOAD_DIR="/root/traefikBinary/traefik_v${TRAEFIK_VERSION}_linux_amd64"
    if [ ! -d "$DOWNLOAD_DIR" ]; then
        echo "Extraction directory not found: $DOWNLOAD_DIR"
        exit 1
    fi
}

# Install function
install_binary() {
    echo "Stopping Traefik service..."
    if ! systemctl stop traefik.service 2>/dev/null; then
        echo "No existing Traefik service found, continuing with installation..."
    fi
    sleep 2

    echo "Installing new Traefik binary..."
    if cp "$DOWNLOAD_DIR/traefik" "$INSTALL_DIR/traefik"; then
        chown root:root "$INSTALL_DIR/traefik"
        chmod 755 "$INSTALL_DIR/traefik"
        echo "Binary permissions set successfully"
    else
        echo "Failed to install new Traefik binary"
        systemctl start traefik.service 2>/dev/null
        exit 1
    fi
}

# Run installation
download_traefik
install_binary

echo "Traefik v$TRAEFIK_VERSION has been installed successfully"
traefik version
