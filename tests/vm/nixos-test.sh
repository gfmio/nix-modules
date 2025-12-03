#!/usr/bin/env bash
# NixOS VM integration test
# This script runs inside a NixOS VM to test NixOS configuration
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

# Check if running on NixOS
check_nixos() {
    log_info "Checking if running on NixOS..."

    if [[ -f /etc/NIXOS ]]; then
        log_success "Running on NixOS"
    else
        log_error "Not running on NixOS"
        exit 1
    fi
}

# Check if Nix is available
check_nix() {
    log_info "Checking Nix installation..."

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

# Build NixOS configuration
build_nixos_config() {
    log_info "Building NixOS configuration..."

    cd ~/nix-modules

    # Try to build a NixOS configuration
    # First, check what configurations are available
    local configs
    configs=$(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]' 2>/dev/null || true)

    if [[ -z "$configs" ]]; then
        log_info "No NixOS configurations found in flake, skipping build test"
        return 0
    fi

    local first_config
    first_config=$(echo "$configs" | head -1)
    log_info "Building NixOS configuration: $first_config"

    if nix build ".#nixosConfigurations.${first_config}.config.system.build.toplevel" --dry-run 2>&1; then
        log_success "NixOS configuration '$first_config' can be built"
    else
        log_error "NixOS configuration '$first_config' build failed"
        exit 1
    fi
}

# Test module evaluation
test_module_eval() {
    log_info "Testing module evaluation..."

    cd ~/nix-modules

    # Try to evaluate NixOS modules
    local configs
    configs=$(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]' 2>/dev/null || true)

    if [[ -z "$configs" ]]; then
        log_info "No NixOS configurations found, skipping evaluation test"
        return 0
    fi

    local first_config
    first_config=$(echo "$configs" | head -1)

    # Test that we can evaluate configuration options
    if nix eval ".#nixosConfigurations.${first_config}.config.system.stateVersion" 2>&1; then
        log_success "Module evaluation works"
    else
        log_error "Module evaluation failed"
        exit 1
    fi
}

# Test NixOS modules are available
test_nixos_modules() {
    log_info "Testing NixOS modules..."

    cd ~/nix-modules

    # Check if the flake exports nixosModules
    local has_modules
    has_modules=$(nix flake show --json 2>/dev/null | jq -r 'has("nixosModules")' 2>/dev/null || echo "false")

    if [[ "$has_modules" == "true" ]]; then
        log_success "NixOS modules are exported"
    else
        log_info "No nixosModules exported (this is OK if not intended)"
    fi
}

# Main
main() {
    echo "============================================"
    echo "  NixOS VM Integration Test"
    echo "============================================"
    echo ""

    check_nixos
    check_nix
    check_flakes
    run_flake_check
    build_nixos_config
    test_module_eval
    test_nixos_modules

    echo ""
    log_success "All NixOS VM tests passed!"
}

main "$@"
