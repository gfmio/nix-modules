#!/usr/bin/env bash
# Setup script for macOS VM base image
# This script installs nix, homebrew, and nix-darwin on a clean macOS installation
# Run this on a freshly cloned macOS VM to create the test base image

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

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS"
        exit 1
    fi
    log_success "Running on macOS $(sw_vers -productVersion)"
}

# Install Xcode Command Line Tools
install_xcode_cli() {
    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools already installed"
    else
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install || true
        # Wait for installation
        until xcode-select -p &>/dev/null; do
            log_info "Waiting for Xcode CLI installation..."
            sleep 5
        done
        log_success "Xcode Command Line Tools installed"
    fi
}

# Install Homebrew
install_homebrew() {
    if command -v brew &>/dev/null; then
        log_success "Homebrew already installed"
        brew update
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        log_success "Homebrew installed"
    fi
}

# Install Nix using Determinate Systems installer
install_nix() {
    if command -v nix &>/dev/null; then
        log_success "Nix already installed: $(nix --version)"
    else
        log_info "Installing Nix via Determinate Systems installer..."
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

        # Source nix for this session
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi

        log_success "Nix installed: $(nix --version)"
    fi
}

# Configure Nix
configure_nix() {
    log_info "Configuring Nix..."

    # Ensure experimental features are enabled
    mkdir -p ~/.config/nix
    if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    fi

    log_success "Nix configured with flakes support"
}

# Install nix-darwin
install_nix_darwin() {
    if command -v darwin-rebuild &>/dev/null; then
        log_success "nix-darwin already installed"
    else
        log_info "Installing nix-darwin..."

        # Bootstrap nix-darwin
        nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
        ./result/bin/darwin-installer

        log_success "nix-darwin installed"
    fi
}

# Install essential tools via Homebrew
install_brew_essentials() {
    log_info "Installing essential Homebrew packages..."

    brew install \
        git \
        jq \
        yq \
        coreutils \
        || true

    log_success "Essential Homebrew packages installed"
}

# Install essential tools via Nix
install_nix_essentials() {
    log_info "Installing essential Nix packages..."

    # Install packages to user profile
    nix profile install nixpkgs#direnv nixpkgs#cachix || true

    log_success "Essential Nix packages installed"
}

# Configure SSH for easier access
configure_ssh() {
    log_info "Configuring SSH..."

    # Enable SSH (requires admin privileges)
    sudo systemsetup -setremotelogin on 2>/dev/null || log_warn "Could not enable SSH - may require manual setup"

    # Create SSH directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    log_success "SSH configured"
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
        PROFILE_FILE=~/.zshrc
        touch "$PROFILE_FILE"
    fi

    # Add nix-daemon source if not present
    if ! grep -q "nix-daemon.sh" "$PROFILE_FILE" 2>/dev/null; then
        cat >> "$PROFILE_FILE" << 'EOF'

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
EOF
    fi

    # Add Homebrew to PATH if not present
    if ! grep -q "homebrew" "$PROFILE_FILE" 2>/dev/null; then
        cat >> "$PROFILE_FILE" << 'EOF'

# Homebrew
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
EOF
    fi

    # Add direnv hook if not present
    if ! grep -q "direnv hook" "$PROFILE_FILE" 2>/dev/null; then
        cat >> "$PROFILE_FILE" << 'EOF'

# Direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi
EOF
    fi

    log_success "Shell profile configured"
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

    if command -v brew &>/dev/null; then
        log_success "✓ brew: $(brew --version | head -1)"
    else
        log_error "✗ brew not found"
        errors=$((errors + 1))
    fi

    if command -v darwin-rebuild &>/dev/null; then
        log_success "✓ darwin-rebuild available"
    else
        log_warn "⚠ darwin-rebuild not found (optional)"
    fi

    if command -v git &>/dev/null; then
        log_success "✓ git: $(git --version)"
    else
        log_error "✗ git not found"
        errors=$((errors + 1))
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
    echo "  macOS Base Image Setup Complete"
    echo "============================================"
    echo ""
    echo "Installed components:"
    echo "  - Xcode Command Line Tools"
    echo "  - Homebrew"
    echo "  - Nix (with flakes enabled)"
    echo "  - nix-darwin (if installed)"
    echo "  - Essential CLI tools"
    echo ""
    echo "Next steps:"
    echo "  1. Save this VM as your test base image"
    echo "  2. Clone this image for each test run"
    echo ""
}

# Main function
main() {
    echo "============================================"
    echo "  macOS VM Base Image Setup"
    echo "============================================"
    echo ""

    check_macos
    install_xcode_cli
    install_homebrew
    install_nix
    configure_nix
    install_brew_essentials
    install_nix_essentials
    configure_ssh
    setup_shell_profile

    # nix-darwin is optional - it can be installed by the flake itself
    # install_nix_darwin

    echo ""
    verify_installation
    print_summary
}

# Run main function
main "$@"
