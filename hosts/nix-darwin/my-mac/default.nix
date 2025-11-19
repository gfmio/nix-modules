{ inputs, config, pkgs, ... }:

{
  # System configuration
  networking.hostName = "my-mac";

  # Nix configuration
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      interval = { Weekday = 7; };
      options = "--delete-older-than 7d";
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # Homebrew (optional)
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";

    taps = [];
    brews = [];
    casks = [];
  };

  # User configuration
  users.users.my-user = {
    home = "/Users/my-user";
  };

  system.stateVersion = 5;
}
