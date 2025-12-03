#!/usr/bin/env bash
# Download NixOS ISO for Packer builds
set -euo pipefail

ISO_URL="${ISO_URL:-https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-aarch64-linux.iso}"
ISO_PATH="${ISO_PATH:-/tmp/nixos-minimal-aarch64.iso}"

if [[ -f "$ISO_PATH" ]]; then
    echo "ISO already exists: $ISO_PATH"
    exit 0
fi

echo "Downloading NixOS ISO..."
echo "  URL: $ISO_URL"
echo "  Destination: $ISO_PATH"

curl -L -o "$ISO_PATH" "$ISO_URL"

echo "Download complete: $ISO_PATH"
