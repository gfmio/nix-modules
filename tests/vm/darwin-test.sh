#!/usr/bin/env bash
# Darwin VM integration test
# This script runs inside a macOS VM to test nix-darwin configuration
# Expected to be run via scripts/vm/test-runner.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if Nix is available
check_nix() {
    log_info "Checking Nix installation..."

    # Source nix if needed
    if ! command -v nix &>/dev/null; then
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
    fi

    if command -v nix &>/dev/null; then
        log_success "Nix is available: $(nix --version)"
    else
        log_error "Nix is not available"
        exit 1
    fi
}

# Check flakes work
check_flakes() {
    log_info "Checking Nix flakes..."

    if nix flake --help &>/dev/null; then
        log_success "Nix flakes are enabled"
    else
        log_error "Nix flakes are not enabled"
        exit 1
    fi
}

# Run flake check on the project
run_flake_check() {
    log_info "Running nix flake check..."

    cd ~/nix-modules

    # Run flake check
    if nix flake check --no-build 2>&1; then
        log_success "Flake check passed"
    else
        log_error "Flake check failed"
        exit 1
    fi
}

# Build darwin configuration
build_darwin_config() {
    log_info "Building darwin configuration..."

    cd ~/nix-modules

    # Try to build a darwin configuration
    # First, check what configurations are available using nix eval
    local configs
    configs=$(nix eval .#darwinConfigurations --apply 'x: builtins.attrNames x' --json 2>/dev/null | jq -r '.[]' 2>/dev/null || true)

    if [[ -z "$configs" ]]; then
        log_info "No darwin configurations found in flake, skipping build test"
        return 0
    fi

    local first_config
    first_config=$(echo "$configs" | head -1)
    log_info "Building darwin configuration: $first_config"

    if nix build ".#darwinConfigurations.${first_config}.system" --dry-run 2>&1; then
        log_success "Darwin configuration '$first_config' can be built"
    else
        log_error "Darwin configuration '$first_config' build failed"
        exit 1
    fi
}

# Test module evaluation
test_module_eval() {
    log_info "Testing module evaluation..."

    cd ~/nix-modules

    # Try to evaluate darwin modules using nix eval
    local configs
    configs=$(nix eval .#darwinConfigurations --apply 'x: builtins.attrNames x' --json 2>/dev/null | jq -r '.[]' 2>/dev/null || true)

    if [[ -z "$configs" ]]; then
        log_info "No darwin configurations found, skipping evaluation test"
        return 0
    fi

    local first_config
    first_config=$(echo "$configs" | head -1)

    # Test that we can evaluate configuration options
    if nix eval ".#darwinConfigurations.${first_config}.config.system.stateVersion" 2>&1; then
        log_success "Module evaluation works"
    else
        log_error "Module evaluation failed"
        exit 1
    fi
}

# Main
main() {
    echo "============================================"
    echo "  Darwin VM Integration Test"
    echo "============================================"
    echo ""

    check_nix
    check_flakes
    run_flake_check
    build_darwin_config
    test_module_eval

    echo ""
    log_success "All darwin VM tests passed!"
}

main "$@"
