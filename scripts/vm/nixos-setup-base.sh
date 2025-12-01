#!/usr/bin/env bash
# Setup script for NixOS VM base image
# This script configures a fresh NixOS installation for testing
# Run this on a freshly cloned NixOS VM to create the test base image

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on NixOS
check_nixos() {
    if [[ ! -f /etc/NIXOS ]]; then
        log_error "This script must be run on NixOS"
        exit 1
    fi
    log_success "Running on NixOS"
}

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root - some user-level configurations may not apply"
    fi
}

# Enable flakes in Nix configuration
enable_flakes() {
    log_info "Ensuring Nix flakes are enabled..."

    # Check if already enabled system-wide
    if grep -q "experimental-features.*flakes" /etc/nix/nix.conf 2>/dev/null; then
        log_success "Flakes already enabled system-wide"
        return 0
    fi

    # Enable for current user
    mkdir -p ~/.config/nix
    if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
        log_success "Flakes enabled for current user"
    else
        log_success "Flakes already enabled for current user"
    fi
}

# Configure SSH
configure_ssh() {
    log_info "Verifying SSH configuration..."

    if systemctl is-active --quiet sshd; then
        log_success "SSH service is running"
    else
        log_warn "SSH service is not running"
        log_info "To enable SSH, add to your NixOS configuration:"
        echo "  services.openssh.enable = true;"
    fi
}

# Install essential packages to user profile
install_essentials() {
    log_info "Installing essential packages to user profile..."

    # These are useful for development but not strictly required
    nix profile install \
        nixpkgs#git \
        nixpkgs#jq \
        nixpkgs#direnv \
        nixpkgs#cachix \
        2>/dev/null || log_warn "Some packages may already be installed"

    log_success "Essential packages installed"
}

# Set up shell profile
setup_shell_profile() {
    log_info "Setting up shell profile..."

    PROFILE_FILE=""
    if [[ -f ~/.zshrc ]]; then
        PROFILE_FILE=~/.zshrc
    elif [[ -f ~/.bashrc ]]; then
        PROFILE_FILE=~/.bashrc
    else
        PROFILE_FILE=~/.bashrc
        touch "$PROFILE_FILE"
    fi

    # Add direnv hook if not present
    if ! grep -q "direnv hook" "$PROFILE_FILE" 2>/dev/null; then
        cat >> "$PROFILE_FILE" << 'EOF'

# Direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook bash)"
fi
EOF
        log_success "Direnv hook added to shell profile"
    else
        log_success "Direnv hook already in shell profile"
    fi
}

# Create a minimal NixOS configuration for testing
create_test_config() {
    log_info "Creating test NixOS configuration template..."

    local config_dir="$HOME/nixos-test-config"
    mkdir -p "$config_dir"

    # Only create if it doesn't exist
    if [[ ! -f "$config_dir/flake.nix" ]]; then
        cat > "$config_dir/flake.nix" << 'EOF'
{
  description = "NixOS Test Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.test-vm = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";  # or x86_64-linux
      modules = [
        ./configuration.nix
      ];
    };
  };
}
EOF

        cat > "$config_dir/configuration.nix" << 'EOF'
{ config, pkgs, ... }:

{
  # Basic system configuration for testing
  system.stateVersion = "24.11";

  # Enable SSH
  services.openssh.enable = true;

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
  ];

  # Nix configuration
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
  };

  # User configuration (adjust as needed)
  users.users.test = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  # Allow wheel group to use sudo without password (for testing)
  security.sudo.wheelNeedsPassword = false;
}
EOF
        log_success "Test configuration template created at $config_dir"
    else
        log_success "Test configuration already exists at $config_dir"
    fi
}

# Warm up the Nix store with common packages
warmup_nix_store() {
    log_info "Warming up Nix store with common packages..."

    # Pre-download some commonly used packages
    nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz 2>/dev/null || true

    log_success "Nix store warmed up"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    local errors=0

    if command -v nix &>/dev/null; then
        log_success "✓ nix: $(nix --version)"
    else
        log_error "✗ nix not found"
        errors=$((errors + 1))
    fi

    if command -v nixos-rebuild &>/dev/null; then
        log_success "✓ nixos-rebuild available"
    else
        log_error "✗ nixos-rebuild not found"
        errors=$((errors + 1))
    fi

    if command -v git &>/dev/null; then
        log_success "✓ git: $(git --version)"
    else
        log_warn "⚠ git not in PATH (may be available via nix-shell)"
    fi

    # Test nix flakes
    if nix flake --help &>/dev/null; then
        log_success "✓ nix flakes enabled"
    else
        log_error "✗ nix flakes not working"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Installation verification failed with $errors error(s)"
        return 1
    fi

    log_success "All verifications passed!"
    return 0
}

# Print summary
print_summary() {
    echo ""
    echo "============================================"
    echo "  NixOS Base Image Setup Complete"
    echo "============================================"
    echo ""
    echo "Configured components:"
    echo "  - Nix with flakes enabled"
    echo "  - Essential CLI tools"
    echo "  - Direnv integration"
    echo "  - Test configuration template"
    echo ""
    echo "Next steps:"
    echo "  1. Save this VM as your test base image"
    echo "  2. Clone this image for each test run"
    echo ""
}

# Main function
main() {
    echo "============================================"
    echo "  NixOS VM Base Image Setup"
    echo "============================================"
    echo ""

    check_nixos
    check_privileges
    enable_flakes
    configure_ssh
    install_essentials
    setup_shell_profile
    create_test_config
    # warmup_nix_store  # Optional, can take a while

    echo ""
    verify_installation
    print_summary
}

# Run main function
main "$@"
