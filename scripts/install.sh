#!/bin/bash

# ==============================================================================
# GitHub Release Installer
# Usage: ./install.sh [user/repo] [binary_name]
# ==============================================================================

set -e

REPO=${1:-"Tejaromalius/granch"}
BINARY_NAME=${2:-"granch"}
INSTALL_DIR="$HOME/.local/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==>${NC} Installing ${GREEN}$BINARY_NAME${NC} from ${GREEN}$REPO${NC}..."

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Fetch latest release data
echo -e "${BLUE}==>${NC} Fetching latest release info..."
RELEASE_DATA=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")

if echo "$RELEASE_DATA" | grep -q "Not Found"; then
    echo -e "${RED}Error:${NC} No releases found for $REPO. Make sure it has at least one public release."
    exit 1
fi

# Detect OS and Architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) echo -e "${RED}Error:${NC} Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Special case for Darwin (macOS)
if [[ "$OS" == "darwin" ]]; then
    OS="darwin"
fi

echo -e "${BLUE}==>${NC} Detected platform: ${GREEN}$OS/$ARCH${NC}"

# Find the best asset match
# We look for assets containing the OS and ARCH in their name
ASSET_URL=$(echo "$RELEASE_DATA" | jq -r ".assets[] | select(.name | contains(\"$OS\") and contains(\"$ARCH\")) | .browser_download_url" | head -n 1)

if [ -z "$ASSET_URL" ] || [ "$ASSET_URL" == "null" ]; then
    echo -e "${RED}Error:${NC} Could not find a suitable asset for your platform."
    echo -e "Available assets:"
    echo "$RELEASE_DATA" | jq -r '.assets[].name'
    exit 1
fi

ASSET_NAME=$(basename "$ASSET_URL")
echo -e "${BLUE}==>${NC} Downloading ${GREEN}$ASSET_NAME${NC}..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -L -o "$TMP_DIR/$ASSET_NAME" "$ASSET_URL"

# Extraction logic
if [[ "$ASSET_NAME" == *.tar.gz ]]; then
    tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR"
    # Find the binary in the extracted files (might be in a subdirectory)
    find "$TMP_DIR" -type f -name "$BINARY_NAME" -exec mv {} "$INSTALL_DIR/$BINARY_NAME" \;
elif [[ "$ASSET_NAME" == *.zip ]]; then
    unzip -o "$TMP_DIR/$ASSET_NAME" -d "$TMP_DIR"
    find "$TMP_DIR" -type f -name "$BINARY_NAME" -exec mv {} "$INSTALL_DIR/$BINARY_NAME" \;
else
    # Assume it's a direct binary
    mv "$TMP_DIR/$ASSET_NAME" "$INSTALL_DIR/$BINARY_NAME"
fi

chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo -e "${GREEN}SUCCESS:${NC} Installed $BINARY_NAME to $INSTALL_DIR"

# Add to PATH logic
SHELL_RC=""
case "$SHELL" in
    */bash) SHELL_RC="$HOME/.bashrc" ;;
    */zsh)  SHELL_RC="$HOME/.zshrc" ;;
    *)      SHELL_RC="$HOME/.profile" ;;
esac

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${BLUE}==>${NC} Adding $INSTALL_DIR to PATH in $SHELL_RC"
    echo "" >> "$SHELL_RC"
    echo "# Added by $BINARY_NAME installer" >> "$SHELL_RC"
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
    echo -e "${BLUE}==>${NC} Please run: ${GREEN}source $SHELL_RC${NC}"
else
    echo -e "${BLUE}==>${NC} $INSTALL_DIR is already in your PATH."
fi

echo -e "${GREEN}==>${NC} You can now run: ${GREEN}$BINARY_NAME --version${NC}"
