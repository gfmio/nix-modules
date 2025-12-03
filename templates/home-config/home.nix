{ config, pkgs, ... }:

{
  home = {
    username = "user";
    homeDirectory = "/home/user";
    stateVersion = "24.11";
  };
  programs = {
    git.enable = true;
    home-manager.enable = true;
  };
}
