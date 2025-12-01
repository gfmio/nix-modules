#!/usr/bin/env bash
# Generic test runner for tart VMs
# This script handles: clone base image → start VM → wait for SSH → run tests → cleanup

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
VM_USER="${VM_USER:-admin}"
VM_SSH_PORT="${VM_SSH_PORT:-22}"
SSH_TIMEOUT="${SSH_TIMEOUT:-120}"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Print usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <base-image> <test-script>

Run tests in an ephemeral tart VM.

Arguments:
  base-image    Name of the tart base image to clone
  test-script   Script to run on the VM (can be a local file or inline command)

Options:
  -u, --user USER       SSH user (default: admin)
  -t, --timeout SECS    SSH connection timeout in seconds (default: 120)
  -k, --keep            Keep the VM after tests (don't destroy)
  -n, --name NAME       Custom name for test VM (default: auto-generated)
  -c, --copy PATH       Copy additional files/directories to VM
  -e, --env VAR=VALUE   Set environment variable in VM
  -v, --verbose         Enable verbose output
  -h, --help            Show this help message

Examples:
  # Run a test script on a macOS VM
  $(basename "$0") macos-nix-base ./tests/vm/darwin-test.sh

  # Run inline commands
  $(basename "$0") nixos-nix-base "nix flake check"

  # Copy the project and run tests
  $(basename "$0") -c . macos-nix-base "cd nix-modules && nix flake check"

  # Keep VM for debugging
  $(basename "$0") --keep macos-nix-base ./tests/vm/darwin-test.sh

Environment Variables:
  VM_USER         SSH user (default: admin)
  VM_SSH_PORT     SSH port (default: 22)
  SSH_TIMEOUT     SSH connection timeout (default: 120)
EOF
    exit 0
}

# Parse arguments
parse_args() {
    KEEP_VM=false
    VERBOSE=false
    CUSTOM_VM_NAME=""
    COPY_PATHS=()
    ENV_VARS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                VM_USER="$2"
                shift 2
                ;;
            -t|--timeout)
                SSH_TIMEOUT="$2"
                shift 2
                ;;
            -k|--keep)
                KEEP_VM=true
                shift
                ;;
            -n|--name)
                CUSTOM_VM_NAME="$2"
                shift 2
                ;;
            -c|--copy)
                COPY_PATHS+=("$2")
                shift 2
                ;;
            -e|--env)
                ENV_VARS+=("$2")
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -lt 2 ]]; then
        log_error "Missing required arguments"
        usage
    fi

    BASE_IMAGE="$1"
    TEST_SCRIPT="$2"
    shift 2

    # Any remaining arguments are passed to the test script
    TEST_ARGS=("$@")
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    if ! command -v tart &>/dev/null; then
        log_error "tart is not installed. Install with: brew install cirruslabs/cli/tart"
        exit 1
    fi

    if ! tart list | grep -q "^${BASE_IMAGE}[[:space:]]"; then
        log_error "Base image '$BASE_IMAGE' not found"
        log_info "Available images:"
        tart list
        exit 1
    fi

    log_success "Prerequisites satisfied"
}

# Generate unique VM name
generate_vm_name() {
    if [[ -n "$CUSTOM_VM_NAME" ]]; then
        TEST_VM_NAME="$CUSTOM_VM_NAME"
    else
        TEST_VM_NAME="${BASE_IMAGE}-test-$(date +%s)-$$"
    fi
    log_info "Test VM name: $TEST_VM_NAME"
}

# Clone base image
clone_vm() {
    log_step "Cloning base image '$BASE_IMAGE' → '$TEST_VM_NAME'..."
    tart clone "$BASE_IMAGE" "$TEST_VM_NAME"
    log_success "VM cloned"
}

# Start VM
start_vm() {
    log_step "Starting VM '$TEST_VM_NAME'..."
    tart run "$TEST_VM_NAME" --no-graphics &
    TART_PID=$!
    log_info "VM started with PID $TART_PID"
}

# Wait for SSH to become available
wait_for_ssh() {
    log_step "Waiting for SSH to become available (timeout: ${SSH_TIMEOUT}s)..."

    local start_time=$(date +%s)
    local vm_ip=""

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        if [[ $elapsed -ge $SSH_TIMEOUT ]]; then
            log_error "Timeout waiting for SSH after ${SSH_TIMEOUT}s"
            return 1
        fi

        # Try to get VM IP
        vm_ip=$(tart ip "$TEST_VM_NAME" 2>/dev/null || true)

        if [[ -n "$vm_ip" ]]; then
            # Try SSH connection
            if ssh $SSH_OPTIONS "$VM_USER@$vm_ip" "exit 0" 2>/dev/null; then
                VM_IP="$vm_ip"
                log_success "SSH available at $VM_USER@$VM_IP (took ${elapsed}s)"
                return 0
            fi
        fi

        if [[ $VERBOSE == true ]]; then
            log_info "Waiting... (${elapsed}s elapsed, IP: ${vm_ip:-unknown})"
        fi

        sleep 2
    done
}

# Copy files to VM
copy_files_to_vm() {
    if [[ ${#COPY_PATHS[@]} -eq 0 ]]; then
        return 0
    fi

    log_step "Copying files to VM..."

    for path in "${COPY_PATHS[@]}"; do
        local basename=$(basename "$path")
        log_info "Copying $path → ~/$basename"
        scp $SSH_OPTIONS -r "$path" "$VM_USER@$VM_IP:~/$basename"
    done

    log_success "Files copied"
}

# Run the test script
run_tests() {
    log_step "Running tests..."

    # Build environment variable exports
    local env_exports=""
    for env_var in "${ENV_VARS[@]}"; do
        env_exports+="export $env_var; "
    done

    local exit_code=0

    if [[ -f "$TEST_SCRIPT" ]]; then
        # Copy and execute script file
        local script_name=$(basename "$TEST_SCRIPT")
        scp $SSH_OPTIONS "$TEST_SCRIPT" "$VM_USER@$VM_IP:~/$script_name"
        ssh $SSH_OPTIONS "$VM_USER@$VM_IP" "${env_exports}chmod +x ~/$script_name && ~/$script_name ${TEST_ARGS[*]:-}" || exit_code=$?
    else
        # Execute inline command
        ssh $SSH_OPTIONS "$VM_USER@$VM_IP" "${env_exports}$TEST_SCRIPT ${TEST_ARGS[*]:-}" || exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "Tests passed"
    else
        log_error "Tests failed with exit code $exit_code"
    fi

    return $exit_code
}

# Stop VM
stop_vm() {
    log_step "Stopping VM..."

    if [[ -n "${TART_PID:-}" ]] && kill -0 "$TART_PID" 2>/dev/null; then
        kill "$TART_PID" 2>/dev/null || true
        wait "$TART_PID" 2>/dev/null || true
        log_success "VM stopped"
    else
        # Try to stop via tart if PID method didn't work
        tart stop "$TEST_VM_NAME" 2>/dev/null || true
    fi
}

# Destroy VM
destroy_vm() {
    if [[ "$KEEP_VM" == true ]]; then
        log_warn "Keeping VM '$TEST_VM_NAME' (use 'tart delete $TEST_VM_NAME' to remove)"
        return 0
    fi

    log_step "Destroying VM '$TEST_VM_NAME'..."
    tart delete "$TEST_VM_NAME" 2>/dev/null || true
    log_success "VM destroyed"
}

# Cleanup function for trap
cleanup() {
    local exit_code=$?
    echo ""
    log_info "Cleaning up..."
    stop_vm
    destroy_vm
    exit $exit_code
}

# Main function
main() {
    parse_args "$@"

    echo "============================================"
    echo "  Tart VM Test Runner"
    echo "============================================"
    echo ""

    # Set up cleanup trap
    trap cleanup EXIT INT TERM

    check_prerequisites
    generate_vm_name
    clone_vm
    start_vm
    wait_for_ssh
    copy_files_to_vm
    run_tests

    # If we get here, tests passed
    # cleanup will be called by trap
}

# Run main function
main "$@"
