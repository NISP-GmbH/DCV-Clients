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

# Define the expected mount volume name
MOUNT_VOLUME="DCVViewer"


# Package build directory
PKG_BUILD_DIR="build"

# Directory to copy the app
DCV_VIEWER_APP_DIR="build/Applications/"

# Directory to install  the app
DCV_SYSTEM_APP_DIR="/Applications/"

# Package PKG name
PKG_FILE_NAME="DCVViewerInstaller.pkg"
PKG_INSTALLER_FILE_NAME="DCVViewerInstaller-signed.pkg"

# Package details
PKG_IDENTIFIER="com.nicesoftware.DcvViewer"
PKG_VERSION="1.0"
PKG_SIGN_ID="NISP"

# No-interaction action
NO_INTERACTION_ACTION=""

# ----------------------------
# Function Definitions
# ----------------------------

# Function to download a file using curl
download_file() {
    local url="$1"
    local output="$2"
    echo "Downloading $url..."
    curl -k -L --fail -o "$output" "$url"
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
        echo "SHA256 verification failed for $DMG_NAME. Installation aborted."
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
    MOUNT_OUTPUT=$(hdiutil attach "$dmg_file" -nobrowse -noautoopen -plist -mountpoint "/Volumes/$mount_volume" 2>&1) || {
        echo "Failed to mount $dmg_file."
        echo "Failed to mount $dmg_file. It might already be mounted or another issue occurred."
        exit 1
    }

    # Parse the mount point using xmllint
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | xmllint --xpath "string(//key[text()='mount-point']/following-sibling::string[1])" - 2>/dev/null)

    if [[ -z "$MOUNT_POINT" ]]; then
        echo "Failed to retrieve the mount point."
        echo "Failed to retrieve the mount point for $dmg_file. Installation aborted."

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

# Function to create the package directory structure
create_pkg_directories() {
    mkdir -p $DCV_VIEWER_APP_DIR
}

# Function to build the PKG
build_pkg() {
    python3 quickpkg "$(pwd)/build/Applications/$APP_NAME" --postinstall $(pwd)/scripts/postinstall --preinstall $(pwd)/scripts/preinstall --output $(pwd)/${PKG_FILE_NAME}
}

# Function to create the Product Package
project_build_pkg() {
    productbuild --package $PKG_FILE_NAME \
                 --sign "${PKG_SIGN_ID}" \
                 $PKG_INSTALLER_FILE_NAME
}

# Function to create the package
create_pkg() {
    echo "Starting installation process..."

    # Create the package builder directories
    create_pkg_directories

    # Download DMG
    download_file "$DMG_URL" "$DMG_NAME"

    # Download SHA256 checksum
    download_file "$SHA256_URL" "$SHA256_NAME"

    # Verify checksum
    verify_sha256 "$DMG_NAME" "$SHA256_NAME"

    # Mount the DMG
    mount_dmg "$DMG_NAME" "$MOUNT_VOLUME"

    #ditto "$MOUNT_POINT/" "$DCV_VIEWER_APP_DIR"
    cp -R "$MOUNT_POINT/$APP_NAME" "$DCV_VIEWER_APP_DIR"
    echo "Copied $APP_NAME to $DCV_VIEWER_APP_DIR."
    
    if [ -f "$DCV_VIEWER_APP_DIR/Applications" ] 
    then
        rm "$DCV_VIEWER_APP_DIR/Applications"
    fi

    # Unmount the DMG
    unmount_dmg "$MOUNT_POINT"

    # Clean up downloaded files
    echo "Cleaning up downloaded files..."
    rm -f "$DMG_NAME" "$SHA256_NAME"
    echo "Cleanup completed."

    if [ ! -d "${DCV_VIEWER_APP_DIR}/${APP_NAME}" ]
    then
        echo "ERRO: $APP_NAME not found in ${DCV_VIEWER_APP_DIR}!"
        exit 1
    fi

    # Build the package
    build_pkg

    # Create the product Package signed by your Dev Team ID
    #project_build_pkg
}

main() {
    create_pkg
    exit 0
}

# ----------------------------
# Main Script Execution
# ----------------------------

main

# unknown error
exit 255
