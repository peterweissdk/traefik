#!/bin/bash

# Global variables
VERSION=""
LOG_DIR="/var/log/"
LOG_FILE="${LOG_DIR}/update_traefik.log"
DOWNLOAD_DIR=""

# Initialize environment and create necessary directories/files
init() {
    # Create log directory and file if they don't exist
    mkdir -p "${LOG_DIR}"
    if [ ! -d "${LOG_DIR}" ]; then
        echo "ERROR: Failed to create log directory ${LOG_DIR}" >&2
        exit 1
    fi
    chmod 755 "${LOG_DIR}"  # rwxr-xr-x
    
    if [ ! -f "${LOG_FILE}" ]; then
        touch "${LOG_FILE}"
        if [ ! -f "${LOG_FILE}" ]; then
            echo "ERROR: Failed to create log file ${LOG_FILE}" >&2
            exit 1
        fi
        chmod 644 "${LOG_FILE}"  # rw-r--r--
    fi

    # Test if we can write to the log file
    if ! echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Log system initialized" >> "${LOG_FILE}"; then
        echo "ERROR: Cannot write to log file ${LOG_FILE}" >&2
        exit 1
    fi
}

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
    for cmd in traefik wget tar jq systemctl; do
        if ! command_exists "$cmd"; then
            log "ERROR" "Required command '$cmd' is not installed."
            exit 1
        fi
    done
    log "INFO" "All required dependencies are installed."
}

# Get and validate current version
get_current_version() {
    local version
    version=$(traefik version | grep "Version:" | awk '{print $2}')
    if [ -z "$version" ]; then
        log "ERROR" "Could not determine current Traefik version"
        exit 1
    fi

    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "ERROR" "Invalid version format '$version'. Expected format: x.y.z"
        exit 1
    fi
    echo "$version"
}

# Get and validate latest version from GitHub
get_github_version() {
    local version
    version=$(wget -qO- https://api.github.com/repos/traefik/traefik/releases/latest | jq -r .tag_name)
    if [ -z "$version" ]; then
        log "ERROR" "Could not fetch latest version from GitHub"
        exit 1
    fi

    # Remove 'v' prefix
    version=${version#v}

    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "ERROR" "Invalid GitHub version format '$version'. Expected format: x.y.z"
        exit 1
    fi
    echo "$version"
}

# Check versions and prompt for update
check_version() {
    local current_version github_version
    current_version=$(get_current_version)
    github_version=$(get_github_version)

    log "INFO" "Current Traefik version: $current_version"
    log "INFO" "Latest GitHub version:   $github_version"

    if [ "$current_version" = "$github_version" ]; then
        log "INFO" "You have the latest version of Traefik installed."
        exit -1
    fi

    log "INFO" "A newer version of Traefik is available."
    read -p "Do you want to update Traefik to v$github_version? (y/N): " response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "INFO" "Update cancelled."
        exit -1
    fi

    VERSION=$github_version
    log "INFO" "Proceeding with update to v$VERSION"
}

# Download and extract new version
download_traefik() {
    mkdir -p /root/traefikBinary
    cd /root/traefikBinary || exit 1

    log "INFO" "Downloading Traefik v$VERSION..."
    if ! wget "https://github.com/traefik/traefik/releases/download/v$VERSION/traefik_v${VERSION}_linux_amd64.tar.gz"; then
        log "ERROR" "Failed to download Traefik"
        exit 1
    fi

    log "INFO" "Extracting Traefik binary..."
    if ! tar xzvf "traefik_v${VERSION}_linux_amd64.tar.gz" --one-top-level; then
        log "ERROR" "Failed to extract Traefik archive"
        exit 1
    fi

    # Set DOWNLOAD_DIR to the extracted directory
    DOWNLOAD_DIR="/root/traefikBinary/traefik_v${VERSION}_linux_amd64"
    if [ ! -d "$DOWNLOAD_DIR" ]; then
        log "ERROR" "Extraction directory not found: $DOWNLOAD_DIR"
        exit 1
    fi
}

# Install new binary
install_binary() {
    log "INFO" "Stopping Traefik service..."
    if ! systemctl stop traefik.service; then
        log "ERROR" "Failed to stop Traefik service"
        cleanup
        exit 1
    fi

    log "INFO" "Installing new Traefik binary..."
    if cp traefik/traefik /usr/local/bin/traefik; then
        chown root:root /usr/local/bin/traefik
        chmod 755 /usr/local/bin/traefik
        log "INFO" "Binary permissions set successfully"
    else
        log "ERROR" "Failed to install new Traefik binary"
        systemctl start traefik.service
        cleanup
        exit 1
    fi

    log "INFO" "Starting Traefik service..."
    if ! systemctl start traefik.service; then
        log "ERROR" "Failed to start Traefik service"
        exit 1
    fi
}

# Cleanup extracted files
cleanup() {
    log "INFO" "Cleaning up extracted files..."
    rm -rf "$DOWNLOAD_DIR"

    if [ -d "$DOWNLOAD_DIR" ]; then
        log "ERROR" "Failed to remove directory: $DOWNLOAD_DIR"
        exit 1
    fi
}

# Main execution
init
log "INFO" "Starting Traefik update process"
check_dependencies
check_version
download_traefik
install_binary
cleanup

log "INFO" "Traefik has been successfully updated to v$VERSION"
traefik version
