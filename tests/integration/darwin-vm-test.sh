#!/usr/bin/env bash
# Integration test for nix-darwin using tart VM
# This script is meant to be run in CI/CD with a tart VM

set -euo pipefail

# Configuration
VM_NAME="${TART_VM_NAME:-sonoma-base}"
VM_CLONE="${TART_VM_CLONE:-darwin-test-$(date +%s)}"
VM_USER="${TART_VM_USER:-admin}"

echo "🧪 Darwin VM Integration Test"
echo "================================"

# Function to cleanup
cleanup() {
    echo "🧹 Cleaning up..."
    if tart list | grep -q "$VM_CLONE"; then
        tart delete "$VM_CLONE" || true
    fi
}

trap cleanup EXIT

# Clone the base VM
echo "📦 Cloning base VM: $VM_NAME -> $VM_CLONE"
tart clone "$VM_NAME" "$VM_CLONE"

# Start the VM
echo "🚀 Starting VM: $VM_CLONE"
tart run "$VM_CLONE" &
TART_PID=$!

# Wait for VM to be ready
echo "⏳ Waiting for VM to be ready..."
sleep 30

# Get VM IP
VM_IP=$(tart ip "$VM_CLONE")
echo "📍 VM IP: $VM_IP"

# Run tests via SSH
echo "🧪 Running tests on VM..."

# Copy the flake to the VM
echo "📤 Copying flake to VM..."
scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$(pwd)" "${VM_USER}@${VM_IP}:~/nix-modules"

# Install Nix if not already installed
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${VM_USER}@${VM_IP}" bash <<'EOF'
if ! command -v nix &> /dev/null; then
    echo "📦 Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOF

# Build and activate the configuration
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${VM_USER}@${VM_IP}" bash <<'EOF'
set -euo pipefail

echo "🔨 Building darwin configuration..."
cd ~/nix-modules

# Build the configuration
nix build .#darwinConfigurations.my-mac.system --extra-experimental-features "nix-command flakes"

# Run basic validation
echo "✅ Checking if configuration built successfully..."
if [ -L result ]; then
    echo "✅ Darwin configuration built successfully!"
    ls -la result/
else
    echo "❌ Build failed - result symlink not found"
    exit 1
fi

# Test that we can query configuration options
echo "🔍 Testing configuration evaluation..."
nix eval .#darwinConfigurations.my-mac.config.system.stateVersion --extra-experimental-features "nix-command flakes"

echo "✅ All tests passed!"
EOF

echo "✅ Darwin VM integration tests completed successfully!"
