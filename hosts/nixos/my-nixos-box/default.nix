{ inputs, config, pkgs, ... }:

{
  imports = [
    # Include hardware configuration
    # ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Minimal filesystem configuration (override in actual hardware-configuration.nix)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # System configuration
  networking.hostName = "my-nixos-box";
  time.timeZone = "UTC";

  # Enable basic services
  services.openssh.enable = true;
  networking.networkmanager.enable = true;

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
