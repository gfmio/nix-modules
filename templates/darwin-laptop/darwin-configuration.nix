{ config, pkgs, ... }:

{
  networking.hostName = "laptop";

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  system.stateVersion = 5;
}
