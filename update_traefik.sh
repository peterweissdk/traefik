#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: update_traefik.sh
# Description: Tool designed to update Traefik
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-05-07
# Version: v0.1.0
# Usage: Run script, or add it to cron
# ----------------------------------------------------------------------------

# Global variables
VERSION=""
LOG_DIR="/var/log/"
LOG_FILE="${LOG_DIR}/update_traefik.log"
DOWNLOAD_DIR=""
DOWNLOAD_DIR_BASE="/root/traefikBinary/"
INSTALL_DIR="/usr/local/bin"
GITHUB_API_URL="https://api.github.com/repos/traefik/traefik/releases/latest"

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
    version=$(wget -qO- "$GITHUB_API_URL" | jq -r .tag_name)
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
    echo "#####Extracted files#####"
    if ! tar xzvf "traefik_v${VERSION}_linux_amd64.tar.gz" --one-top-level; then
        log "ERROR" "Failed to extract Traefik archive"
        exit 1
    fi
    echo "#########################"

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
        exit 1
    fi
    sleep 2

    log "INFO" "Installing new Traefik binary..."
    if cp "$DOWNLOAD_DIR/traefik" "$INSTALL_DIR/traefik"; then
        chown root:root "$INSTALL_DIR/traefik"
        chmod 755 "$INSTALL_DIR/traefik"
        log "INFO" "Binary permissions set successfully"
    else
        log "ERROR" "Failed to install new Traefik binary"
        systemctl start traefik.service
        exit 1
    fi

    log "INFO" "Starting Traefik service..."
    if ! systemctl start traefik.service; then
        log "ERROR" "Failed to start Traefik service"
        exit 1
    fi
    sleep 2
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

# Update function containing main execution
update() {
    init
    log "INFO" "Starting Traefik update process"
    check_dependencies
    check_version
    download_traefik
    install_binary
    cleanup
    log "INFO" "Traefik has been successfully updated to v$VERSION"
    traefik version
}

# Rollback function
rollback() {
    init
    log "INFO" "Starting Traefik rollback process"
    
    # Check if base directory exists
    if [ ! -d "$DOWNLOAD_DIR_BASE" ]; then
        log "ERROR" "No download directory found at: $DOWNLOAD_DIR_BASE"
        exit 1
    fi

    # Find all traefik tar files
    files=("$DOWNLOAD_DIR_BASE"traefik_v*_linux_amd64.tar.gz)
    if [ ! -e "${files[0]}" ]; then
        log "ERROR" "No Traefik archives found in $DOWNLOAD_DIR_BASE"
        exit 1
    fi

    # Create numbered list of versions
    echo "Available versions for rollback:"
    declare -a versions
    for i in "${!files[@]}"; do
        version=$(echo "${files[$i]}" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+')
        versions[$i]=$version
        echo "$((i+1))) $version"
    done
    # Add exit option
    echo "$((${#versions[@]}+1))) Exit"

    # Get user choice
    read -p "Select version to rollback to (1-$((${#versions[@]}+1))): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((${#versions[@]}+1)) ]; then
        log "ERROR" "Invalid selection"
        exit 1
    fi

    # Check if user chose to exit
    if [ "$choice" -eq $((${#versions[@]}+1)) ]; then
        log "INFO" "Rollback cancelled by user"
        exit 0
    fi

    # Set selected version and archive
    selected_version=${versions[$((choice-1))]}
    selected_file=${files[$((choice-1))]}
    
    log "INFO" "Rolling back to version $selected_version"
    
    # Extract the selected archive
    if ! tar xzvf "$selected_file" --one-top-level -C "$DOWNLOAD_DIR_BASE"; then
        log "ERROR" "Failed to extract Traefik archive"
        exit 1
    fi

    # Set DOWNLOAD_DIR to the extracted directory
    DOWNLOAD_DIR="${DOWNLOAD_DIR_BASE}traefik_${selected_version}_linux_amd64"
    if [ ! -d "$DOWNLOAD_DIR" ]; then
        log "ERROR" "Extraction directory not found: $DOWNLOAD_DIR"
        exit 1
    fi

    # Use existing install_binary function to install
    install_binary
    
    # Clean up extracted files
    cleanup
    
    log "INFO" "Successfully rolled back to $selected_version"
    traefik version
}

# Main script execution
main() {
    # Parse command line arguments
    while getopts "ur" flag; do
        case "${flag}" in
            u) 
                update
                return 0
                ;;
            r)
                rollback
                return 0
                ;;
            *)
                log "ERROR" "Invalid option. Usage: $0 [-u|-r]"
                return 1
                ;;
        esac
    done

    # If no flags are provided, show usage
    if [ $OPTIND -eq 1 ]; then
        echo -e "ERROR: No options were passed.\nUsage: $0 [-u|-r]\n  -u: Update Traefik\n  -r: Rollback to previous version"
        return 1
    fi
}

# Execute main and exit with its return code
main "$@"
exit $?
