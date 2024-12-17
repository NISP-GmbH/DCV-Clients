#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ----------------------------
# Configuration Variables
# ----------------------------

ORIGINAL_SCRIPT="install_dcv_client.sh"
LOGO_IMAGE="logo.png"  # Ensure this is logo.png; convert from jpg if necessary
MARKER="__LOGO__"
OUTPUT_SCRIPT_PREFIX="install_dcv_client_"

# ----------------------------
# Function Definitions
# ----------------------------

# Function to display usage
usage() {
    echo "Usage: $0"
    echo "Ensure that '$ORIGINAL_SCRIPT' and '$LOGO_IMAGE' are in the current directory."
    exit 1
}

# Check if required files exist
if [[ ! -f "$ORIGINAL_SCRIPT" ]]; then
    echo "Error: '$ORIGINAL_SCRIPT' not found in the current directory."
    usage
fi

if [[ ! -f "$LOGO_IMAGE" ]]; then
    echo "Error: '$LOGO_IMAGE' not found in the current directory."
    usage
fi

# Prompt for company name
read -p "Enter the company name: " COMPANY_NAME

# Validate company name
if [[ -z "$COMPANY_NAME" ]]; then
    echo "Error: Company name cannot be empty."
    exit 1
fi

# Generate output script name
OUTPUT_SCRIPT="${OUTPUT_SCRIPT_PREFIX}${COMPANY_NAME}.sh"

# Check for invalid characters in company name for filename safety
if [[ "$COMPANY_NAME" =~ [^a-zA-Z0-9_-] ]]; then
    echo "Error: Company name contains invalid characters. Use only letters, numbers, underscores, or hyphens."
    exit 1
fi

# Encode logo.png to Base64 without line breaks
BASE64_LOGO=$(base64 < "$LOGO_IMAGE" | tr -d '\n')

# Create the combined script
{
    # Copy the original installation script content
    cat "$ORIGINAL_SCRIPT"

    # Append the exit statement to prevent shell from executing embedded data
    echo ""
    echo "exit 0"

    # Append the marker
    echo "$MARKER"

    # Append the Base64-encoded image
    echo "$BASE64_LOGO"
} > "$OUTPUT_SCRIPT"

# Make the output script executable
chmod +x "$OUTPUT_SCRIPT"

echo "Successfully created '$OUTPUT_SCRIPT' with the embedded logo."
echo "You can distribute this single script to users."
