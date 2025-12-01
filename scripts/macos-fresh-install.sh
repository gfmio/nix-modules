#!/usr/bin/env bash
# Fresh macOS installation and setup script
# Designed for remote installs, automated setups, and bootstrapping new machines
#
# Usage:
#   # Basic install (interactive)
#   curl -fsSL https://raw.githubusercontent.com/gfmio/nix-modules/main/scripts/macos-fresh-install.sh | bash
#
#   # Non-interactive with options
#   curl -fsSL ... | bash -s -- --non-interactive --hostname my-mac --user myuser
#
#   # Or run locally
#   ./macos-fresh-install.sh [OPTIONS]
#
# Options:
#   --hostname NAME       Set the hostname
#   --user NAME           Create/configure this user
#   --ssh-key "KEY"       Add SSH public key for remote access
#   --ssh-key-url URL     Fetch SSH key from URL (e.g., GitHub)
#   --skip-nix            Skip Nix installation
#   --skip-homebrew       Skip Homebrew installation
#   --skip-xcode          Skip Xcode CLI tools
#   --with-nix-darwin     Install nix-darwin
#   --with-rosetta        Install Rosetta 2 (for Apple Silicon)
#   --non-interactive     Run without prompts
#   --flake-url URL       Clone and apply a nix-darwin flake
#   --help                Show this help

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Defaults (can be overridden via environment or flags)
HOSTNAME="${HOSTNAME:-}"
TARGET_USER="${TARGET_USER:-}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
SSH_KEY_URL="${SSH_KEY_URL:-}"
SKIP_NIX="${SKIP_NIX:-false}"
SKIP_HOMEBREW="${SKIP_HOMEBREW:-false}"
SKIP_XCODE="${SKIP_XCODE:-false}"
WITH_NIX_DARWIN="${WITH_NIX_DARWIN:-false}"
WITH_ROSETTA="${WITH_ROSETTA:-false}"
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
FLAKE_URL="${FLAKE_URL:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Logging
# ============================================================================

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $1"; }

# ============================================================================
# Argument Parsing
# ============================================================================

show_help() {
    cat << 'EOF'
Fresh macOS Installation Script

Usage: macos-fresh-install.sh [OPTIONS]

Options:
  --hostname NAME       Set the machine hostname
  --user NAME           Create/configure this user (defaults to current user)
  --ssh-key "KEY"       Add SSH public key for remote access
  --ssh-key-url URL     Fetch SSH key from URL (e.g., https://github.com/user.keys)
  --skip-nix            Skip Nix installation
  --skip-homebrew       Skip Homebrew installation
  --skip-xcode          Skip Xcode CLI tools installation
  --with-nix-darwin     Install nix-darwin
  --with-rosetta        Install Rosetta 2 (Apple Silicon only)
  --non-interactive     Run without prompts (use defaults)
  --flake-url URL       Apply a nix-darwin flake after installation
  --help                Show this help message

Environment Variables:
  HOSTNAME              Machine hostname
  TARGET_USER           User to configure
  SSH_PUBLIC_KEY        SSH public key to add
  SSH_KEY_URL           URL to fetch SSH key from
  NON_INTERACTIVE       Set to 'true' for non-interactive mode

Examples:
  # Basic interactive setup
  ./macos-fresh-install.sh

  # Remote bootstrap with SSH key from GitHub
  curl -fsSL URL | bash -s -- --ssh-key-url https://github.com/myuser.keys --non-interactive

  # Full automated setup with nix-darwin flake
  ./macos-fresh-install.sh --non-interactive --with-nix-darwin --flake-url github:myuser/dotfiles

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_PUBLIC_KEY="$2"
                shift 2
                ;;
            --ssh-key-url)
                SSH_KEY_URL="$2"
                shift 2
                ;;
            --skip-nix)
                SKIP_NIX=true
                shift
                ;;
            --skip-homebrew)
                SKIP_HOMEBREW=true
                shift
                ;;
            --skip-xcode)
                SKIP_XCODE=true
                shift
                ;;
            --with-nix-darwin)
                WITH_NIX_DARWIN=true
                shift
                ;;
            --with-rosetta)
                WITH_ROSETTA=true
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --flake-url)
                FLAKE_URL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# ============================================================================
# System Checks
# ============================================================================

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS"
        exit 1
    fi

    local macos_version
    macos_version=$(sw_vers -productVersion)
    log_success "Running on macOS $macos_version"

    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        log_info "Apple Silicon detected (arm64)"
    else
        log_info "Intel Mac detected ($arch)"
    fi
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            log_error "Sudo access required but running non-interactively"
            log_info "Please run with: sudo -v && ./macos-fresh-install.sh --non-interactive"
            exit 1
        fi
        log_info "Some steps require administrator privileges"
        sudo -v
    fi

    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# ============================================================================
# Installation Functions
# ============================================================================

install_rosetta() {
    if [[ "$(uname -m)" != "arm64" ]]; then
        log_info "Rosetta not needed on Intel Mac"
        return 0
    fi

    if /usr/bin/pgrep -q oahd; then
        log_success "Rosetta 2 already installed"
        return 0
    fi

    log_step "Installing Rosetta 2..."
    softwareupdate --install-rosetta --agree-to-license
    log_success "Rosetta 2 installed"
}

install_xcode_cli() {
    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools already installed"
        return 0
    fi

    log_step "Installing Xcode Command Line Tools..."

    # Trigger installation
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]*//')
    softwareupdate -i "$PROD" --verbose

    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    # Verify installation
    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools installed"
    else
        log_error "Xcode CLI installation failed"
        exit 1
    fi
}

install_homebrew() {
    if command -v brew &>/dev/null; then
        log_success "Homebrew already installed"
        brew update || true
        return 0
    fi

    log_step "Installing Homebrew..."

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Add to current session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_success "Homebrew installed"
}

install_nix() {
    if command -v nix &>/dev/null; then
        log_success "Nix already installed: $(nix --version)"
        return 0
    fi

    log_step "Installing Nix via Determinate Systems installer..."

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    else
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    fi

    # Source nix for this session
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        # shellcheck source=/dev/null
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi

    log_success "Nix installed: $(nix --version)"
}

install_nix_darwin() {
    if command -v darwin-rebuild &>/dev/null; then
        log_success "nix-darwin already installed"
        return 0
    fi

    log_step "Installing nix-darwin..."

    # Use nix-build to get the installer
    nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer --out-link /tmp/darwin-installer

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        # Non-interactive installation
        /tmp/darwin-installer/bin/darwin-installer --no-confirm
    else
        /tmp/darwin-installer/bin/darwin-installer
    fi

    rm -f /tmp/darwin-installer

    log_success "nix-darwin installed"
}

# ============================================================================
# Configuration Functions
# ============================================================================

configure_hostname() {
    if [[ -z "$HOSTNAME" ]]; then
        return 0
    fi

    log_step "Setting hostname to: $HOSTNAME"

    sudo scutil --set ComputerName "$HOSTNAME"
    sudo scutil --set HostName "$HOSTNAME"
    sudo scutil --set LocalHostName "$HOSTNAME"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$HOSTNAME"

    log_success "Hostname set to $HOSTNAME"
}

configure_ssh() {
    log_step "Configuring SSH..."

    # Enable SSH (Remote Login)
    if sudo systemsetup -getremotelogin | grep -q "Off"; then
        sudo systemsetup -setremotelogin on
        log_success "SSH (Remote Login) enabled"
    else
        log_success "SSH already enabled"
    fi

    # Set up SSH directory
    local ssh_dir="${HOME}/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # Fetch SSH key from URL if provided
    if [[ -n "$SSH_KEY_URL" ]]; then
        log_info "Fetching SSH key from: $SSH_KEY_URL"
        local fetched_key
        fetched_key=$(curl -fsSL "$SSH_KEY_URL" 2>/dev/null || true)
        if [[ -n "$fetched_key" ]]; then
            SSH_PUBLIC_KEY="$fetched_key"
        else
            log_warn "Could not fetch SSH key from URL"
        fi
    fi

    # Add SSH public key if provided
    if [[ -n "$SSH_PUBLIC_KEY" ]]; then
        local auth_keys="$ssh_dir/authorized_keys"
        touch "$auth_keys"
        chmod 600 "$auth_keys"

        # Add key if not already present (check first line of provided keys)
        local first_key
        first_key=$(echo "$SSH_PUBLIC_KEY" | head -n1)
        if ! grep -qF "$first_key" "$auth_keys" 2>/dev/null; then
            echo "$SSH_PUBLIC_KEY" >> "$auth_keys"
            log_success "SSH public key(s) added"
        else
            log_info "SSH key already present"
        fi
    fi

    log_success "SSH configured"
}

configure_nix() {
    log_step "Configuring Nix..."

    # User nix config
    local nix_conf_dir="${HOME}/.config/nix"
    mkdir -p "$nix_conf_dir"

    local nix_conf="$nix_conf_dir/nix.conf"
    if [[ ! -f "$nix_conf" ]] || ! grep -q "experimental-features" "$nix_conf" 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> "$nix_conf"
    fi

    log_success "Nix configured with flakes support"
}

configure_shell_profile() {
    log_step "Configuring shell profile..."

    local profile_file="${HOME}/.zshrc"
    touch "$profile_file"

    # Nix daemon
    if ! grep -q "nix-daemon.sh" "$profile_file" 2>/dev/null; then
        cat >> "$profile_file" << 'PROFILE_NIX'

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
PROFILE_NIX
    fi

    # Homebrew
    if ! grep -q "homebrew" "$profile_file" 2>/dev/null; then
        cat >> "$profile_file" << 'PROFILE_BREW'

# Homebrew
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
PROFILE_BREW
    fi

    log_success "Shell profile configured"
}

apply_flake() {
    if [[ -z "$FLAKE_URL" ]]; then
        return 0
    fi

    log_step "Applying nix-darwin flake: $FLAKE_URL"

    # Ensure nix-darwin is available
    if ! command -v darwin-rebuild &>/dev/null; then
        log_warn "darwin-rebuild not found, installing nix-darwin first..."
        install_nix_darwin
    fi

    # Apply the flake
    darwin-rebuild switch --flake "$FLAKE_URL"

    log_success "Flake applied successfully"
}

# ============================================================================
# Essential Tools
# ============================================================================

install_essentials() {
    log_step "Installing essential tools..."

    # Homebrew essentials
    if command -v brew &>/dev/null; then
        brew install git curl wget jq || true
    fi

    # Nix essentials
    if command -v nix &>/dev/null; then
        nix profile install nixpkgs#direnv nixpkgs#cachix || true
    fi

    log_success "Essential tools installed"
}

# ============================================================================
# Verification
# ============================================================================

verify_installation() {
    log_step "Verifying installation..."

    local errors=0

    # Check Nix
    if [[ "$SKIP_NIX" != "true" ]]; then
        if command -v nix &>/dev/null; then
            log_success "Nix: $(nix --version)"
            if nix flake --help &>/dev/null; then
                log_success "Nix flakes: enabled"
            else
                log_error "Nix flakes: not working"
                errors=$((errors + 1))
            fi
        else
            log_error "Nix: not found"
            errors=$((errors + 1))
        fi
    fi

    # Check Homebrew
    if [[ "$SKIP_HOMEBREW" != "true" ]]; then
        if command -v brew &>/dev/null; then
            log_success "Homebrew: $(brew --version | head -1)"
        else
            log_error "Homebrew: not found"
            errors=$((errors + 1))
        fi
    fi

    # Check git
    if command -v git &>/dev/null; then
        log_success "Git: $(git --version)"
    else
        log_warn "Git: not found"
    fi

    # Check SSH
    if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        log_success "SSH: enabled"
    else
        log_warn "SSH: not enabled"
    fi

    # Check nix-darwin
    if [[ "$WITH_NIX_DARWIN" == "true" ]]; then
        if command -v darwin-rebuild &>/dev/null; then
            log_success "nix-darwin: installed"
        else
            log_error "nix-darwin: not found"
            errors=$((errors + 1))
        fi
    fi

    echo ""
    if [[ $errors -gt 0 ]]; then
        log_error "Verification completed with $errors error(s)"
        return 1
    else
        log_success "All verifications passed!"
        return 0
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    local ip_addr
    ip_addr=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")

    echo ""
    echo "============================================"
    echo "  macOS Fresh Install Complete"
    echo "============================================"
    echo ""
    echo "System Information:"
    echo "  Hostname: $(scutil --get ComputerName 2>/dev/null || echo 'not set')"
    echo "  IP Address: $ip_addr"
    echo "  User: $(whoami)"
    echo ""
    echo "Installed Components:"
    [[ "$SKIP_XCODE" != "true" ]] && echo "  - Xcode Command Line Tools"
    [[ "$SKIP_HOMEBREW" != "true" ]] && echo "  - Homebrew"
    [[ "$SKIP_NIX" != "true" ]] && echo "  - Nix (with flakes)"
    [[ "$WITH_NIX_DARWIN" == "true" ]] && echo "  - nix-darwin"
    [[ "$WITH_ROSETTA" == "true" ]] && echo "  - Rosetta 2"
    echo ""
    echo "Remote Access:"
    echo "  SSH: ssh $(whoami)@$ip_addr"
    echo ""
    if [[ -n "$FLAKE_URL" ]]; then
        echo "Applied Flake:"
        echo "  $FLAKE_URL"
        echo ""
    fi
    echo "Next Steps:"
    echo "  - Start a new shell or run: source ~/.zshrc"
    echo "  - Test nix: nix run nixpkgs#hello"
    [[ "$WITH_NIX_DARWIN" == "true" ]] && echo "  - Rebuild: darwin-rebuild switch"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_args "$@"

    echo "============================================"
    echo "  macOS Fresh Installation Script"
    echo "============================================"
    echo ""

    check_macos
    check_sudo

    # Installation steps
    [[ "$WITH_ROSETTA" == "true" ]] && install_rosetta
    [[ "$SKIP_XCODE" != "true" ]] && install_xcode_cli
    [[ "$SKIP_HOMEBREW" != "true" ]] && install_homebrew
    [[ "$SKIP_NIX" != "true" ]] && install_nix
    [[ "$SKIP_NIX" != "true" ]] && configure_nix
    [[ "$WITH_NIX_DARWIN" == "true" ]] && install_nix_darwin

    # Configuration steps
    configure_hostname
    configure_ssh
    configure_shell_profile
    install_essentials

    # Apply flake if specified
    [[ -n "$FLAKE_URL" ]] && apply_flake

    # Verify and summarize
    echo ""
    verify_installation
    print_summary
}

main "$@"
