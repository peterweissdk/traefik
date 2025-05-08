#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: setup_traefik.sh
# Description: Configure Traefik environment, permissions, and service
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-05-08
# Version: v0.1.0
# Usage: Run script as root
# ----------------------------------------------------------------------------

# Exit on error
set -e

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

echo "Setting up Traefik environment..."

# Give Traefik binary the ability to bind to privileged ports
echo "Configuring port binding capabilities..."
setcap 'cap_net_bind_service=+ep' /usr/local/bin/traefik

# Setup Traefik user and group
echo "Creating Traefik user and group..."
groupadd -f traefik
useradd \
    -g traefik --no-user-group \
    -d /etc/traefik --no-create-home \
    -s /usr/sbin/nologin \
    -r traefik 2>/dev/null || true

# Create directories and files
echo "Creating configuration directories..."
mkdir -p /etc/traefik
mkdir -p /etc/traefik/dynamic
mkdir -p /etc/traefik/acme

# Create and set permissions for acme.json
echo "Setting up ACME configuration..."
touch /etc/traefik/acme/acme.json
chmod 600 /etc/traefik/acme/acme.json

# Set directory ownership
echo "Setting directory permissions..."
chown -R root:root /etc/traefik
chown -R traefik:traefik /etc/traefik/dynamic
chown -R traefik:traefik /etc/traefik/acme

# Create and configure .env file
#echo "Creating environment file..."
#touch /etc/traefik/.env
#chmod 600 /etc/traefik/.env

# Create and configure log files
echo "Setting up log files..."
touch /var/log/traefik.log
touch /var/log/traefik-access.log
chown traefik:traefik /var/log/traefik.log
chown traefik:traefik /var/log/traefik-access.log

# Copy systemd service file
echo "Installing systemd service..."
SCRIPT_DIR="$(dirname "$0")"
cp "$SCRIPT_DIR/traefik.service" /lib/systemd/system/traefik.service

# Set service file permissions
echo "Setting service file permissions..."
chown root:root /lib/systemd/system/traefik.service
chmod 644 /lib/systemd/system/traefik.service

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Traefik setup completed successfully!"
exit 0
