#!/bin/bash

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Setup container and dependencies
setup_container() {
    # Find next available CTID
    ctid=100  # Start checking from ID 100
    while pct status $ctid >/dev/null 2>&1; do
        ((ctid++))
    done
    CTID=$ctid
    echo "Using next available CTID: $CTID"
    HOSTNAME="traefik-proxy"  # Container hostname
    TEMPLATE="ubuntu-24.04-standard"
    STORAGE="local"
    MEMORY="1024"
    SWAP="1024"
    CORES="1"
    DISK_SIZE="8"
    TAG="proxy"

    # Create container
    echo "Creating container..."
    pct create "$CTID" "local:vztmpl/$TEMPLATE" \
        --hostname "$HOSTNAME" \
        --memory "$MEMORY" \
        --swap "$SWAP" \
        --cores "$CORES" \
        --rootfs "$STORAGE:$DISK_SIZE" \
        --unprivileged 1 \
        --tags "$TAG" \
        --onboot 1 \
        --start 1 || { echo "Failed to create container"; exit 1; }

    # Wait for container to start
    echo "Waiting for container to start..."
    sleep 10

    # Install required packages
    echo "Installing required packages..."
    pct exec "$CTID" -- apt-get update
    pct exec "$CTID" -- apt-get install -y wget tar jq

    # Create required directories
    echo "Creating directories..."
    pct exec "$CTID" -- mkdir -p /root/traefikBinary
    pct exec "$CTID" -- mkdir -p /root/script
}

# Install Traefik and setup scripts
install_traefik() {
    # Download update script
    echo "Downloading update script..."
    pct exec "$CTID" -- wget -O /root/script/update_traefik.sh https://raw.githubusercontent.com/peterweissdk/traefik/main/update_traefik.sh

    # Set permissions
    echo "Setting permissions..."
    pct exec "$CTID" -- chown root:root /root/script/update_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/script/update_traefik.sh

    # Create installation script
    cat > /tmp/install_traefik.sh << 'EOF'
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
EOF

    # Copy and execute installation script in container
    echo "Copying installation script to container..."
    pct push "$CTID" /tmp/install_traefik.sh /root/script/install_traefik.sh

    echo "Setting permissions for installation script..."
    pct exec "$CTID" -- chmod 755 /root/script/install_traefik.sh

    echo "Running Traefik installation..."
    pct exec "$CTID" -- /root/script/install_traefik.sh

    # Cleanup temporary files
    echo "Cleaning up temporary files..."
    rm -f /tmp/install_traefik.sh
}

# Run the functions
setup_container
install_traefik

# Final status message
echo "Container setup complete!"
echo "Container ID: $CTID"
echo "Hostname: $HOSTNAME"
echo "You can access the container with: pct enter $CTID"
