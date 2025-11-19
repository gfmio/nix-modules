{ inputs, config, pkgs, ... }:

{
  imports = [
    # Include hardware configuration
    # ./hardware-configuration.nix
  ];

  # Use features from nixos-features
  features = {
    # Boot configuration
    boot.systemd-boot.enable = true;

    # Core system
    system.kernel.enable = true;
    core.nix.enable = true;

    # Desktop environment
    desktop.gnome = {
      enable = true;
      wayland = true;
    };

    # Hardware
    hardware.audio.enable = true;
    hardware.bluetooth.enable = true;

    # Networking
    network.networking.enable = true;
    network.ssh.enable = true;
  };

  # System configuration
  networking.hostName = "my-nixos-box";
  time.timeZone = "UTC";

  # User configuration
  users.users.my-user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # Allow unfree packages if needed
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
