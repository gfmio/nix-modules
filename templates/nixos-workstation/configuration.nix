{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Enable features
  features = {
    desktop.gnome.enable = true;
    virtualization.docker.enable = true;
  };

  networking.hostName = "workstation";
  system.stateVersion = "24.11";
}
