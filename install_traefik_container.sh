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

# Global variables
CTID=""

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Setup container and dependencies
setup_container() {

    # Container configuration
    ROOT_PASS="traefik"
    MEMORY="1024"
    SWAP="512"
    CORES="1"
    DISK_SIZE="8"
    TAG="proxy"
    HOSTNAME="traefik-proxy"  # Container hostname
    TEMPLATE="ubuntu-24.04-standard"

    # Network configuration
    read -p "Enter IP address for container (e.g., 192.168.1.10/24): " IP_ADDRESS
    read -p "Enter gateway IP address (e.g., 192.168.1.1): " GATEWAY

    # Validate IP address format
    if [[ ! $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Error: Invalid IP address format. Expected format: xxx.xxx.xxx.xxx/xx"
        exit 1
    fi

    # Validate gateway format
    if [[ ! $GATEWAY =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid gateway format. Expected format: xxx.xxx.xxx.xxx"
        exit 1
    fi

    # Check if IP is already in use
    IP_WITHOUT_MASK=$(echo $IP_ADDRESS | cut -d'/' -f1)
    if ping -c 1 -W 1 $IP_WITHOUT_MASK >/dev/null 2>&1; then
        echo "Error: IP address $IP_WITHOUT_MASK is already in use"
        exit 1
    fi

    # List available storages and prompt for selection
    echo "Available storages:"
    pvesm status
    read -p "Enter storage name: " STORAGE
    STORAGE=${STORAGE:-local}

    # Validate storage exists and supports containers
    if ! pvesm status | grep -q "^$STORAGE"; then
        echo "Error: Storage '$STORAGE' not found"
        exit 1
    fi

    # Find next available CTID
    ctid=100  # Start checking from ID 100
    while true; do
        # Check if ID is used by either a container or VM
        if ! pct status $ctid >/dev/null 2>&1 && ! qm status $ctid >/dev/null 2>&1; then
            break  # ID is available
        fi
        ((ctid++))
    done
    CTID=$ctid
    export CTID
    echo "Using next available CTID: $CTID"

    # Find template path
    echo "Searching for template: ${TEMPLATE}"
    TEMPLATE_PATH=$(pveam list $STORAGE | grep "${TEMPLATE}" | awk '{print $1}')
    echo "Found template path: ${TEMPLATE_PATH}"
    if [ -z "$TEMPLATE_PATH" ]; then
        echo "Error: Template '${TEMPLATE}' not found in storage '${STORAGE}'"
        exit 1
    fi

    # Create container
    echo "Creating container..."
    pct create "$CTID" "$TEMPLATE_PATH" \
        --hostname "$HOSTNAME" \
        --password "$ROOT_PASS" \
        --memory "$MEMORY" \
        --swap "$SWAP" \
        --cores "$CORES" \
        --rootfs "$STORAGE:$DISK_SIZE" \
        --unprivileged 1 \
        --features keyctl=1,nesting=1,fuse=1 \
        --tags "$TAG" \
        --onboot 1 \
        --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS,gw=$GATEWAY,type=veth \
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

    # Force root password change on first login
    echo "Setting root password to expire..."
    pct exec "$CTID" -- chage -d 0 root


}

# Install Traefik and setup scripts
install_traefik() {

    # Create required directories
    echo "Creating directories..."
    pct exec "$CTID" -- mkdir -p /root/traefikBinary
    pct exec "$CTID" -- mkdir -p /root/script
    pct exec "$CTID" -- mkdir -p /root/script/traefik_conf

    # Get script directory
    SCRIPT_DIR="$(dirname "$0")"

    echo "Copying all files to container..."
    # Copy all required files
    pct push "$CTID" "$SCRIPT_DIR/traefik_update.sh" /usr/local/bin/traefik_update.sh
    pct push "$CTID" "$SCRIPT_DIR/install_traefik.sh" /root/script/install_traefik.sh
    pct push "$CTID" "$SCRIPT_DIR/setup_traefik.sh" /root/script/setup_traefik.sh
    pct push "$CTID" "$SCRIPT_DIR/traefik.service" /root/script/traefik.service
    pct push "$CTID" "$SCRIPT_DIR/99-traefik-updates" /root/script/99-traefik-updates
    # Copy all files from traefik_conf directory (including hidden files)
    shopt -s dotglob
    for file in "$SCRIPT_DIR"/traefik_conf/*; do
        if [ -f "$file" ]; then
            pct push "$CTID" "$file" "/root/script/traefik_conf/$(basename "$file")"
        fi
    done
    shopt -u dotglob

    # Set all permissions
    echo "Setting file permissions..."
    pct exec "$CTID" -- chown root:root /usr/local/bin/traefik_update.sh
    pct exec "$CTID" -- chmod 755 /usr/local/bin/traefik_update.sh
    pct exec "$CTID" -- chown root:root /root/script/install_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/script/install_traefik.sh
    pct exec "$CTID" -- chown -R root:root /root/script/setup_traefik.sh
    pct exec "$CTID" -- chmod 755 /root/script/setup_traefik.sh
    pct exec "$CTID" -- chown -R root:root /root/script/traefik.service
    pct exec "$CTID" -- chmod 644 /root/script/traefik.service
    pct exec "$CTID" -- chown -R root:root /root/script/99-traefik-updates
    pct exec "$CTID" -- chmod 755 /root/script/99-traefik-updates
    pct exec "$CTID" -- chown -R root:root /root/script/traefik_conf
    pct exec "$CTID" -- chmod 755 /root/script/traefik_conf

    # Run installation
    echo "Running Traefik installation..."
    if ! pct exec "$CTID" -- /root/script/install_traefik.sh; then
        echo "ERROR: Traefik installation failed"
        exit 1
    fi

    # Run setup
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
echo "Password: traefik"
echo "Username: root"

exit 0
