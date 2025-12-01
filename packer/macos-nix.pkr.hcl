packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# Variables
variable "vm_name" {
  type        = string
  default     = "macos-nix-base"
  description = "Name for the macOS VM with Nix"
}

variable "base_image" {
  type        = string
  default     = "ghcr.io/cirruslabs/macos-tahoe-base:latest"
  description = "Base macOS image to build from"
}

variable "cpu_count" {
  type        = number
  default     = 4
  description = "Number of CPUs"
}

variable "memory_gb" {
  type        = number
  default     = 8
  description = "Memory in GB"
}

variable "disk_size_gb" {
  type        = number
  default     = 80
  description = "Disk size in GB"
}

variable "ssh_username" {
  type        = string
  default     = "admin"
  description = "SSH username (Cirrus Labs images use 'admin')"
}

variable "ssh_password" {
  type        = string
  default     = "admin"
  description = "SSH password (Cirrus Labs images use 'admin')"
  sensitive   = true
}

variable "bridged_nic" {
  type        = string
  default     = "en0"
  description = "Network interface for bridged networking (e.g., en0, en1)"
}

variable "use_bridged" {
  type        = bool
  default     = true
  description = "Use bridged networking instead of NAT (recommended for internet access)"
}

variable "install_nix_darwin" {
  type        = bool
  default     = false
  description = "Whether to bootstrap nix-darwin (leave false for base image)"
}

# Source: Build from Cirrus Labs base image
source "tart-cli" "macos-nix" {
  vm_base_name = var.base_image
  vm_name      = var.vm_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = var.disk_size_gb

  # SSH configuration - Cirrus Labs images use admin/admin
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "300s"

  # Networking - use bridged for reliable internet access
  run_extra_args = var.use_bridged ? ["--net-bridged=${var.bridged_nic}"] : []
  ip_extra_args  = var.use_bridged ? ["--resolver=arp"] : []

  # Run headless
  headless = true
}

build {
  sources = ["source.tart-cli.macos-nix"]

  # Provisioner: Install Nix using Determinate Systems installer
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Installing Nix via Determinate Systems installer ==='",
      "",
      "# Check if Nix is already installed",
      "if command -v nix &>/dev/null; then",
      "  echo 'Nix already installed'",
      "  nix --version",
      "else",
      "  # Install Nix",
      "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm",
      "",
      "  # Source nix for this session",
      "  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then",
      "    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh",
      "  fi",
      "",
      "  echo 'Nix installed successfully'",
      "  nix --version",
      "fi",
    ]
  }

  # Provisioner: Configure Nix
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Configuring Nix ==='",
      "",
      "# Source nix",
      "if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then",
      "  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh",
      "fi",
      "",
      "# Ensure experimental features are enabled in user config",
      "mkdir -p ~/.config/nix",
      "if ! grep -q 'experimental-features' ~/.config/nix/nix.conf 2>/dev/null; then",
      "  echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf",
      "fi",
      "",
      "# Test flakes work",
      "nix flake --help > /dev/null",
      "echo 'Nix flakes enabled'",
    ]
  }

  # Provisioner: Set up shell profile for Nix
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Setting up shell profile ==='",
      "",
      "# Add nix-daemon source to .zprofile if not present",
      "if ! grep -q 'nix-daemon.sh' ~/.zprofile 2>/dev/null; then",
      "  cat >> ~/.zprofile << 'NIXPROFILE'",
      "",
      "# Nix",
      "if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then",
      "  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'",
      "fi",
      "NIXPROFILE",
      "fi",
      "",
      "echo 'Shell profile configured'",
    ]
  }

  # Provisioner: Install essential Nix packages
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Installing essential Nix packages ==='",
      "",
      "# Source nix",
      "if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then",
      "  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh",
      "fi",
      "",
      "# Install direnv and cachix to user profile",
      "nix profile install nixpkgs#direnv nixpkgs#cachix || true",
      "",
      "# Add direnv hook to zprofile if not present",
      "if ! grep -q 'direnv hook' ~/.zprofile 2>/dev/null; then",
      "  cat >> ~/.zprofile << 'DIRENVPROFILE'",
      "",
      "# Direnv",
      "if command -v direnv &>/dev/null; then",
      "  eval \"$(direnv hook zsh)\"",
      "fi",
      "DIRENVPROFILE",
      "fi",
      "",
      "echo 'Essential Nix packages installed'",
    ]
  }

  # Provisioner: Verify installation
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Verifying installation ==='",
      "",
      "# Source profiles",
      "source ~/.zprofile || true",
      "",
      "# Check nix",
      "echo 'Nix version:'",
      "nix --version",
      "",
      "# Check flakes",
      "echo 'Testing nix flakes:'",
      "nix flake --help > /dev/null && echo 'Flakes OK'",
      "",
      "# Check brew (should already be installed from base image)",
      "echo 'Homebrew version:'",
      "brew --version | head -1",
      "",
      "echo '=== Installation verified ==='",
    ]
  }

  post-processor "manifest" {
    output     = "macos-nix-manifest.json"
    strip_path = true
  }
}
