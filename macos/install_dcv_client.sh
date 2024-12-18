#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ----------------------------
# Configuration Variables
# ----------------------------

# Updated URLs for the DMG and its SHA256 checksum
DMG_URL="https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-viewer.x86_64.dmg"
SHA256_URL="https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-viewer.x86_64.dmg.sha256sum"

# Extract DMG_NAME from DMG_URL
DMG_NAME=$(basename "$DMG_URL")
SHA256_NAME=$(basename "$SHA256_URL")

# Name of the application inside the DMG (ensure this matches exactly)
APP_NAME="DCV Viewer.app"  # Update this if the app name inside the DMG is different

# Installation directory
INSTALL_LOCATION="/Applications"

# Debug flag
DEBUG=0

# No-interaction action
NO_INTERACTION_ACTION=""

# ----------------------------
# Function Definitions
# ----------------------------

# Function to display usage
usage() {
    echo "Usage: $0 [-debug] [-no-interaction=install|uninstall]"
    exit 1
}

# Function to handle debug messages
debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $1"
    fi
}

# Function to display a dialog and get user choice
get_user_choice() {
    # Determine the script's directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOGO_PATH="$SCRIPT_DIR/logo.png"  # Use logo.png if converted; else use logo.jpg

    # Check if logo.png (or logo.jpg) exists
    if [ -f "$LOGO_PATH" ]; then
        ICON_SPEC="(POSIX file \"$LOGO_PATH\") as alias"
        debug_log "Logo found at $LOGO_PATH. Will use it in the dialog."
    else
        ICON_SPEC="note"
        debug_log "Logo not found at $LOGO_PATH. Using default icon."
    fi

    CHOICE=$(osascript <<END
    tell application "System Events"
        activate
        set userChoice to button returned of (display dialog "Choose an action:" buttons {"Install", "Uninstall", "Cancel"} default button "Install" with icon $ICON_SPEC)
    end tell
END
    )
    echo "$CHOICE"
}

# Function to show informational messages
show_info() {
    local message="$1"
    osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with icon note" >/dev/null
}

# Function to show error messages
show_error() {
    local message="$1"
    osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null
}

# Function to download a file using curl
download_file() {
    local url="$1"
    local output="$2"
    echo "Downloading $url..."
    debug_log "Executing: curl -L --fail -o \"$output\" \"$url\""
    curl -L --fail -o "$output" "$url"
    echo "Downloaded $output."
}

# Function to verify SHA256 checksum
verify_sha256() {
    local dmg_file="$1"
    local sha256_file="$2"

    echo "Verifying SHA256 checksum..."
    # Extract expected hash (assuming the SHA256 file contains the hash followed by the filename)
    expected_hash=$(awk '{print $1}' "$sha256_file")
    # Calculate actual hash
    actual_hash=$(shasum -a 256 "$dmg_file" | awk '{print $1}')

    echo "Expected: $expected_hash"
    echo "Actual:   $actual_hash"

    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo "SHA256 verification passed."
    else
        echo "SHA256 verification failed."
        show_error "SHA256 verification failed for $DMG_NAME. Installation aborted."
        exit 1
    fi
}

# Function to check if the DMG is already mounted
is_mounted() {
    mount | grep "/Volumes/$MOUNT_VOLUME " > /dev/null 2>&1
}

# Function to mount the DMG and retrieve the mount point
mount_dmg() {
    local dmg_file="$1"
    local mount_volume="$2"

    if [ -d "/Volumes/$mount_volume" ]; then
        echo "$mount_volume is already mounted."
        MOUNT_POINT="/Volumes/$mount_volume"
        return
    fi

    echo "Mounting $dmg_file..."
    # Mount the DMG and capture output in plist format
    MOUNT_OUTPUT=$(hdiutil attach "$dmg_file" -nobrowse -noautoopen -plist 2>&1) || {
        echo "Failed to mount $dmg_file."
        show_error "Failed to mount $dmg_file. It might already be mounted or another issue occurred."
        exit 1
    }

    debug_log "hdiutil attach output:"
    debug_log "$MOUNT_OUTPUT"

    # Parse the mount point using xmllint
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | xmllint --xpath "string(//key[text()='mount-point']/following-sibling::string[1])" - 2>/dev/null)

    debug_log "Parsed MOUNT_POINT: $MOUNT_POINT"

    if [[ -z "$MOUNT_POINT" ]]; then
        echo "Failed to retrieve the mount point."
        show_error "Failed to retrieve the mount point for $dmg_file. Installation aborted."
        exit 1
    fi

    echo "Mounted at $MOUNT_POINT."
}

# Function to unmount the DMG
unmount_dmg() {
    local mount_point="$1"
    echo "Unmounting $mount_point..."
    hdiutil detach "$mount_point" -quiet
    echo "Unmounted $mount_point."
}

# Function to install the application
install_app() {
    echo "Starting installation process..."

    # Download DMG
    download_file "$DMG_URL" "$DMG_NAME"

    # Download SHA256 checksum
    download_file "$SHA256_URL" "$SHA256_NAME"

    # Verify checksum
    verify_sha256 "$DMG_NAME" "$SHA256_NAME"

    # Define the expected mount volume name
    MOUNT_VOLUME="DCV Viewer"

    # Mount the DMG
    mount_dmg "$DMG_NAME" "$MOUNT_VOLUME"

    # Install the application using sudo to ensure permissions
    echo "Installing $APP_NAME to $INSTALL_LOCATION..."
    debug_log "Executing: sudo cp -R \"$MOUNT_POINT/$APP_NAME\" \"$INSTALL_LOCATION/\""
    sudo cp -R "$MOUNT_POINT/$APP_NAME" "$INSTALL_LOCATION/"
    echo "Installed $APP_NAME to $INSTALL_LOCATION."

    # Apply configuration settings
    echo "Applying configuration settings..."
    defaults write com.nicesoftware.dcvviewer mouse.enable-control-click-as-right-click -int 0
    defaults write com.nicesoftware.dcvviewer /com/nicesoftware/DcvViewer/state/connection/transport -string "quic"
    echo "Configuration applied: $CONFIG_KEY = $CONFIG_VALUE"

    # Unmount the DMG
    unmount_dmg "$MOUNT_POINT"

    # Clean up downloaded files
    echo "Cleaning up downloaded files..."
    rm -f "$DMG_NAME" "$SHA256_NAME"
    echo "Cleanup completed."

    # Conditionally show success message
    if [[ -z "$NO_INTERACTION_ACTION" ]]; then
        show_info "Installation completed successfully."
    fi
}

# Function to uninstall the application
uninstall_app() {
    echo "Starting uninstallation process..."

    # Define the expected mount volume name
    MOUNT_VOLUME="DCV Viewer"

    # Remove the application using sudo to ensure permissions
    echo "Removing $APP_NAME from $INSTALL_LOCATION..."
    debug_log "Executing: sudo rm -rf \"$INSTALL_LOCATION/$APP_NAME\""
    sudo rm -rf "$INSTALL_LOCATION/$APP_NAME"
    echo "Removed $APP_NAME from $INSTALL_LOCATION."

    # Conditionally show success message
    if [[ -z "$NO_INTERACTION_ACTION" ]]; then
        show_info "Uninstallation completed successfully."
    fi
}

# ----------------------------
# Main Script Execution
# ----------------------------

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -debug)
            DEBUG=1
            set -x  # Enable shell debugging
            ;;
        -no-interaction=*)
            NO_INTERACTION_ACTION="${1#*=}"
            if [[ "$NO_INTERACTION_ACTION" != "install" && "$NO_INTERACTION_ACTION" != "uninstall" ]]; then
                echo "Invalid value for -no-interaction. Use 'install' or 'uninstall'."
                usage
            fi
            ;;
        -*|--*)
            usage
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Function to perform action based on parameters or user choice
perform_action() {
    local action="$1"

    case "$action" in
        "install")
            install_app
            ;;
        "uninstall")
            uninstall_app
            ;;
        *)
            show_error "Unknown action: $action. Exiting."
            exit 1
            ;;
    esac
}

# Determine whether to run non-interactively or prompt the user
if [[ -n "$NO_INTERACTION_ACTION" ]]; then
    perform_action "$NO_INTERACTION_ACTION"
else
    # Prompt user for action via GUI
    USER_CHOICE=$(get_user_choice)

    case "$USER_CHOICE" in
        "Install")
            install_app
            ;;
        "Uninstall")
            uninstall_app
            ;;
        "Cancel")
            echo "Operation cancelled by the user."
            exit 0
            ;;
        *)
            show_error "Unknown option selected. Exiting."
            exit 1
            ;;
    esac
fi
