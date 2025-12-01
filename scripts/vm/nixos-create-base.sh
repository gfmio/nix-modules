#!/usr/bin/env bash
# Create a clean NixOS base image for tart VM testing
# Uses VNC to automate the installation process

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="${VM_NAME:-nixos-clean}"
DISK_SIZE="${DISK_SIZE:-50}"
ISO_URL="${ISO_URL:-https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-aarch64-linux.iso}"
ISO_PATH="${ISO_PATH:-/tmp/nixos-minimal-aarch64.iso}"
VM_USER="${VM_USER:-nixos}"
VM_PASSWORD="${VM_PASSWORD:-nixos}"
VNC_PORT="${VNC_PORT:-5900}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

TART_PID=""
VM_IP=""

cleanup() {
    local exit_code=$?
    if [[ -n "${TART_PID:-}" ]] && kill -0 "$TART_PID" 2>/dev/null; then
        log_info "Stopping VM..."
        kill "$TART_PID" 2>/dev/null || true
        wait "$TART_PID" 2>/dev/null || true
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v tart &>/dev/null; then
        log_error "tart is not installed. Install with: brew install cirruslabs/cli/tart"
        exit 1
    fi

    if tart list | grep -q "^${VM_NAME}[[:space:]]"; then
        log_error "VM '$VM_NAME' already exists. Delete it first with: tart delete $VM_NAME"
        exit 1
    fi

    # Check for VNC automation tools
    if ! command -v python3 &>/dev/null; then
        log_error "python3 is required for VNC automation"
        exit 1
    fi

    # Install vncdotool if not available
    if ! python3 -c "import vncdotool" 2>/dev/null; then
        log_info "Installing vncdotool for VNC automation..."
        pip3 install vncdotool --quiet
    fi

    log_success "Prerequisites satisfied"
}

# Download ISO if needed
download_iso() {
    if [[ -f "$ISO_PATH" ]]; then
        log_info "Using cached ISO: $ISO_PATH"
    else
        log_info "Downloading NixOS ISO..."
        curl -L -o "$ISO_PATH" "$ISO_URL"
        log_success "ISO downloaded"
    fi
}

# Create VM
create_vm() {
    log_info "Creating VM '$VM_NAME' with ${DISK_SIZE}GB disk..."
    tart create --linux --disk-size "$DISK_SIZE" "$VM_NAME"
    log_success "VM created"
}

# Generate the NixOS configuration
generate_nixos_config() {
    cat << 'NIXOS_CONFIG'
{ config, pkgs, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-vm";
  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
  };

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim git curl wget htop tmux
  ];

  services.spice-vdagentd.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11";
}
NIXOS_CONFIG
}

# Send keystrokes via VNC
vnc_type() {
    local text="$1"
    local delay="${2:-0.05}"
    python3 << EOF
import time
from vncdotool import api
client = api.connect('localhost:$VNC_PORT')
time.sleep(0.5)
client.type('$text', delay=$delay)
client.disconnect()
EOF
}

# Send special key via VNC
vnc_key() {
    local key="$1"
    python3 << EOF
from vncdotool import api
import time
client = api.connect('localhost:$VNC_PORT')
time.sleep(0.2)
client.key('$key')
client.disconnect()
EOF
}

# Send a command and press enter
vnc_command() {
    local cmd="$1"
    local wait="${2:-1}"
    vnc_type "$cmd"
    sleep 0.3
    vnc_key "enter"
    sleep "$wait"
}

# Wait for text to appear (by waiting a fixed time, since we can't OCR)
vnc_wait() {
    local seconds="$1"
    local message="${2:-Waiting...}"
    log_info "$message ($seconds seconds)"
    sleep "$seconds"
}

# Start VM with VNC
start_vm_with_vnc() {
    log_info "Starting VM with ISO and VNC enabled..."
    tart run --disk "$ISO_PATH" --vnc --no-graphics "$VM_NAME" &
    TART_PID=$!

    # Wait for VNC to be ready
    sleep 5

    # Wait for VM to get an IP
    log_info "Waiting for VM to boot..."
    local attempts=0
    while [[ $attempts -lt 60 ]]; do
        VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
        if [[ -n "$VM_IP" ]]; then
            log_info "VM IP: $VM_IP"
            break
        fi
        ((attempts++))
        sleep 5
    done

    if [[ -z "$VM_IP" ]]; then
        log_error "Failed to get VM IP"
        exit 1
    fi
}

# Automate the NixOS installation via VNC
run_vnc_installation() {
    log_info "Starting VNC-automated NixOS installation..."

    # Wait for the system to boot to login prompt
    vnc_wait 60 "Waiting for NixOS live environment to boot"

    # Login as root (NixOS live auto-logs in, but let's make sure we have a shell)
    vnc_key "enter"
    sleep 2

    log_info "Setting up SSH in live environment..."

    # Enable SSH and set root password
    vnc_command "systemctl start sshd" 2
    vnc_command "echo 'root:temp' | chpasswd" 2

    log_success "SSH enabled in live environment"

    # Now switch to SSH for the actual installation (more reliable)
    log_info "Switching to SSH for installation..."
    sleep 3

    run_ssh_installation
}

# Run the actual installation via SSH
run_ssh_installation() {
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10"

    # Wait for SSH to be ready
    log_info "Waiting for SSH to be available..."
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if sshpass -p temp ssh $ssh_opts root@"$VM_IP" "echo ok" &>/dev/null; then
            break
        fi
        ((attempts++))
        sleep 2
    done

    if [[ $attempts -ge 30 ]]; then
        log_error "SSH connection failed"
        exit 1
    fi

    log_success "SSH connection established"

    # Run the installation
    log_info "Partitioning and formatting disk..."
    sshpass -p temp ssh $ssh_opts root@"$VM_IP" << 'EOF'
set -euo pipefail

# Partition
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart root ext4 512MB 100%
parted /dev/vda -- mkpart ESP fat32 1MB 512MB
parted /dev/vda -- set 2 esp on
sleep 2

# Format
mkfs.ext4 -L nixos /dev/vda1
mkfs.fat -F 32 -n boot /dev/vda2

# Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Generate config
nixos-generate-config --root /mnt
EOF

    log_success "Disk prepared"

    # Write configuration
    log_info "Writing NixOS configuration..."
    generate_nixos_config | sshpass -p temp ssh $ssh_opts root@"$VM_IP" "cat > /mnt/etc/nixos/configuration.nix"

    # Install NixOS
    log_info "Running nixos-install (this will take several minutes)..."
    sshpass -p temp ssh $ssh_opts root@"$VM_IP" "nixos-install --no-root-passwd 2>&1 | tail -20"

    log_success "NixOS installed"

    # Shutdown
    log_info "Shutting down VM..."
    sshpass -p temp ssh $ssh_opts root@"$VM_IP" "shutdown -h now" || true
    sleep 10
}

# Finalize
finalize() {
    # Ensure VM is stopped
    if [[ -n "${TART_PID:-}" ]] && kill -0 "$TART_PID" 2>/dev/null; then
        kill "$TART_PID" 2>/dev/null || true
        wait "$TART_PID" 2>/dev/null || true
    fi
    TART_PID=""

    echo ""
    log_success "============================================"
    log_success "  NixOS base image '$VM_NAME' is ready!"
    log_success "============================================"
    echo ""
    log_info "User: nixos"
    log_info "Password: nixos"
    log_info "The user has passwordless sudo access."
    echo ""
    log_info "Next steps:"
    echo "  1. Test the VM: tart run $VM_NAME"
    echo "  2. Create test base: task tart:base:nixos"
}

# Fallback: semi-automated installation
run_semi_automated() {
    log_warn "Running semi-automated installation (requires manual VNC interaction)"

    start_vm_with_vnc

    echo ""
    log_info "Please complete these steps in the VM (connect via VNC to localhost:$VNC_PORT):"
    echo "  1. Wait for the system to boot"
    echo "  2. Run: systemctl start sshd"
    echo "  3. Run: echo 'root:temp' | chpasswd"
    echo ""
    read -p "Press Enter once SSH is enabled..."

    run_ssh_installation
    finalize
}

# Main
main() {
    echo "============================================"
    echo "  NixOS Base Image Creator (VNC Automated)"
    echo "============================================"
    echo ""

    check_prerequisites
    download_iso
    create_vm

    # Check for sshpass
    if ! command -v sshpass &>/dev/null; then
        log_warn "sshpass not found. Installing..."
        if command -v brew &>/dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            log_error "Please install sshpass manually"
            exit 1
        fi
    fi

    # Try VNC automation first
    if python3 -c "import vncdotool" 2>/dev/null; then
        start_vm_with_vnc
        run_vnc_installation
        finalize
    else
        log_warn "vncdotool not available, falling back to semi-automated mode"
        run_semi_automated
    fi
}

main "$@"
