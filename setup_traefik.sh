#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: setup_traefik.sh
# Description: Configure Traefik environment, permissions, and service
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-05-09
# Version: v0.1.1
# Usage: Run script as root
# ----------------------------------------------------------------------------

# Exit on error
set -e

# Main setup function
setup_traefik() {
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

    # Set up directory paths
    SCRIPT_DIR="$(dirname "$0")"
    CONF_DIR="$SCRIPT_DIR/traefik_conf"

    # Create directories and files
    echo "Creating configuration directories..."
    mkdir -p /etc/traefik
    mkdir -p /etc/traefik/dynamic
    mkdir -p /etc/traefik/acme

    # Copy main config files
    cp "$CONF_DIR/traefik.yaml" /etc/traefik/traefik.yml
    cp "$CONF_DIR/.env" /etc/traefik/.env
    chmod 600 /etc/traefik/.env

    # Copy dynamic config files
    cp "$CONF_DIR/defaultRouters.yaml" /etc/traefik/dynamic/
    cp "$CONF_DIR/testRoute.yaml" /etc/traefik/dynamic/
    cp "$CONF_DIR/tls.yaml" /etc/traefik/dynamic/
    cp "$CONF_DIR/middlewares.yaml" /etc/traefik/dynamic/

    # Create and set permissions for acme.json
    echo "Setting up ACME configuration..."
    touch /etc/traefik/acme/acme.json
    chmod 600 /etc/traefik/acme/acme.json

    # Set directory ownership
    echo "Setting directory permissions..."
    chown -R root:root /etc/traefik
    chown -R traefik:traefik /etc/traefik/dynamic
    chown -R traefik:traefik /etc/traefik/acme

    # Create and configure log files
    echo "Setting up log files..."
    touch /var/log/traefik.log
    touch /var/log/traefik-access.log
    chown traefik:traefik /var/log/traefik.log
    chown traefik:traefik /var/log/traefik-access.log

    # Copy systemd service file
    echo "Installing systemd service..."
    cp "$SCRIPT_DIR/traefik.service" /lib/systemd/system/traefik.service

    # Set service file permissions
    echo "Setting service file permissions..."
    chown root:root /lib/systemd/system/traefik.service
    chmod 644 /lib/systemd/system/traefik.service

    # Reload systemd
    echo "Reloading systemd daemon..."
    systemctl daemon-reload

    # Enable and start Traefik service
    echo "Enabling Traefik service..."
    systemctl enable traefik.service

    echo "Starting Traefik service..."
    systemctl start traefik.service

    # Check if service is running
    echo "Checking Traefik service status..."
    if ! systemctl is-active --quiet traefik.service; then
        echo "ERROR: Traefik service failed to start"
        systemctl status traefik.service
        return 1
    fi
    echo "Traefik service is running successfully!"

    echo "Traefik setup completed successfully!"
    return 0
}

# Function to configure automatic updates
configure_automatic_updates() {
    echo "Configuring automatic updates..."
    read -p "Would you like to enable automatic Traefik updates? (y/n): " enable_auto_updates

    if [[ "$enable_auto_updates" =~ ^[Yy]$ ]]; then
        # Schedule automatic updates at 3 AM every day
        local cron_job="0 3 * * * /usr/local/bin/traefik_update.sh -u -y"
        echo "Scheduling automatic updates to run daily at 3 AM"

        # Add the cron job
        echo "Current crontab:"
        crontab -l 2>/dev/null || echo "No crontab"
        
        echo "Adding job: $cron_job"
        if ! (crontab -l 2>/dev/null | grep -v "/usr/local/bin/traefik_update.sh"; echo "$cron_job") | crontab - 2>/tmp/crontab_error; then
            echo "ERROR: Failed to modify crontab. Error was: $(cat /tmp/crontab_error)"
            rm -f /tmp/crontab_error
            return 1
        fi
        rm -f /tmp/crontab_error
        
        echo "New crontab:"
        crontab -l 2>/dev/null

        # Verify cron job installation
        if ! crontab -l | grep -q "/usr/local/bin/traefik_update.sh"; then
            echo "ERROR: Failed to install cron job"
            return 1
        else
            echo "Cron job installed successfully"
        fi
    else
        echo "Automatic updates not enabled. No cron job will be installed."
    fi

    # Configure MOTD
    echo "Setting up MOTD for Traefik updates..."
    cp "$(dirname "$0")/99-traefik-updates" /etc/update-motd.d/99-traefik-updates
    chmod +x /etc/update-motd.d/99-traefik-updates

    echo "Cronjob and MOTD configuration completed!"
}

# Run setup and configure updates
setup_traefik
configure_automatic_updates

echo "Traefik setup completed!"

exit 0
