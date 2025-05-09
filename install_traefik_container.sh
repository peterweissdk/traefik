#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: install_traefik_container.sh
# Description: Tool designed to install Traefik in a container
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-05-08
# Version: v0.1.0
# Usage: Run script
# ----------------------------------------------------------------------------

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

    # Wait for container to start with timeout
    echo "Waiting for container to start..."
    timeout=120
    counter=0
    while ! pct status "$CTID" | grep -q running; do
        sleep 1
        ((counter++))
        if [ $counter -ge $timeout ]; then
            echo "Timeout waiting for container to start after $timeout seconds"
            exit 1
        fi
    done
    echo "Container is running"

    # Install required packages
    echo "Installing required packages..."
    pct exec "$CTID" -- apt-get update
    pct exec "$CTID" -- apt-get install -y wget tar jq

    # Configure root autologin
    echo "Configuring root autologin..."
    pct exec "$CTID" -- mkdir -p /etc/systemd/system/console-getty.service.d
    pct exec "$CTID" -- bash -c 'cat > /etc/systemd/system/console-getty.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud console 115200,38400,9600 linux
EOF'
    pct exec "$CTID" -- systemctl daemon-reload

    # Create required directories
    echo "Creating directories..."
    pct exec "$CTID" -- mkdir -p /root/traefikBinary
    pct exec "$CTID" -- mkdir -p /root/script
}

# Install Traefik and setup scripts
install_traefik() {
    # Copy scripts from local directory
    echo "Copying scripts to container..."
    SCRIPT_DIR="$(dirname "$0")"
    
    # Copy update script from local directory
    echo "Copying update script..."
    pct push "$CTID" "$SCRIPT_DIR/update_traefik.sh" /root/traefikBinary/update_traefik.sh
    pct exec "$CTID" -- chown root:root /root/traefikBinary/update_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/traefikBinary/update_traefik.sh

    # Copy and execute installation script
    echo "Copying installation script..."
    pct push "$CTID" "$SCRIPT_DIR/install_traefik.sh" /root/script/install_traefik.sh
    pct exec "$CTID" -- chown root:root /root/script/install_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/script/install_traefik.sh

    echo "Running Traefik installation..."
    if ! pct exec "$CTID" -- /root/script/install_traefik.sh; then
        echo "ERROR: Traefik installation failed"
        exit 1
    fi
    
    echo "Traefik installation completed successfully"

    # Copy and execute setup script
    echo "Copying setup script..."
    pct push "$CTID" "$SCRIPT_DIR/setup_traefik.sh" /root/script/setup_traefik.sh
    pct exec "$CTID" -- chown root:root /root/script/setup_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/script/setup_traefik.sh

    echo "Running Traefik setup..."
    if ! pct exec "$CTID" -- /root/script/setup_traefik.sh; then
        echo "ERROR: Traefik setup failed"
        exit 1
    fi

    echo "Traefik setup completed successfully"
    return 0
}

# Run the functions
setup_container
install_traefik

# Final status message
echo "Container setup complete!"
echo "Container ID: $CTID"
echo "Hostname: $HOSTNAME"
echo "You can access the container with: pct enter $CTID"
echo ""
echo "To generate MD5 hashed passwords to set authentication in middlewares.yaml:"
echo "  openssl passwd -1 \"my-password\""

exit 0
