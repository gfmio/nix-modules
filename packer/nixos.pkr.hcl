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
  default     = "nixos-clean"
  description = "Name for the NixOS VM"
}

variable "iso_url" {
  type        = string
  default     = "https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-aarch64-linux.iso"
  description = "URL to download NixOS ISO"
}

variable "iso_path" {
  type        = string
  default     = "/tmp/nixos-minimal-aarch64.iso"
  description = "Local path to store the ISO"
}

variable "disk_size" {
  type        = number
  default     = 50
  description = "Disk size in GB"
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

variable "ssh_username" {
  type        = string
  default     = "nixos"
  description = "SSH username for the final VM"
}

variable "ssh_password" {
  type        = string
  default     = "nixos"
  description = "SSH password for the final VM"
}

variable "root_password" {
  type        = string
  default     = "temp"
  description = "Temporary root password during installation"
  sensitive   = true
}

# Source: Create NixOS VM from ISO
source "tart-cli" "nixos" {
  vm_name      = var.vm_name
  from_iso     = [var.iso_path]
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = var.disk_size

  # SSH configuration - connecting as root during installation
  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout  = "30m"

  # Headless mode for automated builds
  headless = true

  # Boot command to set up SSH in the live environment
  # NixOS live environment boots to a shell prompt automatically
  boot_wait = "60s"

  boot_command = [
    # Wait for the system to fully boot
    "<wait30>",
    # Start SSH daemon
    "systemctl start sshd<enter>",
    "<wait3>",
    # Set root password for SSH access
    "echo 'root:${var.root_password}' | chpasswd<enter>",
    "<wait2>"
  ]
}

build {
  sources = ["source.tart-cli.nixos"]

  # Provisioner: Partition and format disk
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Partitioning disk ==='",
      "parted /dev/vda -- mklabel gpt",
      "parted /dev/vda -- mkpart root ext4 512MB 100%",
      "parted /dev/vda -- mkpart ESP fat32 1MB 512MB",
      "parted /dev/vda -- set 2 esp on",
      "sleep 2",
      "",
      "echo '=== Formatting partitions ==='",
      "mkfs.ext4 -L nixos /dev/vda1",
      "mkfs.fat -F 32 -n boot /dev/vda2",
      "",
      "echo '=== Mounting filesystems ==='",
      "mount /dev/disk/by-label/nixos /mnt",
      "mkdir -p /mnt/boot",
      "mount /dev/disk/by-label/boot /mnt/boot",
      "",
      "echo '=== Generating hardware configuration ==='",
      "nixos-generate-config --root /mnt"
    ]
  }

  # Provisioner: Write NixOS configuration
  provisioner "file" {
    content = <<-NIXOS_CONFIG
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

      system.stateVersion = "24.11";
    }
    NIXOS_CONFIG
    destination = "/mnt/etc/nixos/configuration.nix"
  }

  # Provisioner: Run nixos-install
  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "",
      "echo '=== Installing NixOS ==='",
      "nixos-install --no-root-passwd",
      "",
      "echo '=== Installation complete ==='",
      "",
      "echo '=== Shutting down ==='",
      "shutdown -h now || true"
    ]
    expect_disconnect = true
  }

  post-processor "manifest" {
    output     = "nixos-manifest.json"
    strip_path = true
  }
}
