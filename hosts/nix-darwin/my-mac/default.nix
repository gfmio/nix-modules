{ pkgs, ... }:

{
  # System configuration
  # Note: networking.hostName is set by mkDarwinSystem
  networking.computerName = "My Mac";
  networking.localHostName = "my-mac";

  system = {
    # Primary user for user-specific settings (homebrew, system.defaults, etc.)
    primaryUser = "my-user";

    # macOS system defaults
    defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
        minimize-to-application = true;
        show-recents = false;
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = false;
        CreateDesktop = false;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "WhenScrolling";
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        "com.apple.swipescrolldirection" = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = false;
      };
    };

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    # System state version
    stateVersion = 5;
  };

  # Nix configuration
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [ "@admin" "my-user" ];

      # Optimize builds
      max-jobs = "auto";
      cores = 0;

      # Caching
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # Store optimization (replaces auto-optimise-store)
    optimise.automatic = true;

    gc = {
      automatic = true;
      interval = { Weekday = 7; };
      options = "--delete-older-than 7d";
    };
  };

  # nixpkgs config
  nixpkgs.config = {
    allowUnfree = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Essential CLI tools
    vim
    git
    curl
    wget
    htop

    # Development tools
    direnv
    nix-direnv

    # Utilities
    jq
    ripgrep
    fd
    tree
  ];

  # Homebrew configuration
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };

    taps = [
      "homebrew/cask-fonts"
      "homebrew/services"
    ];

    brews = [
      # Add your brews here
    ];

    casks = [
      # Add your casks here
      # Example: "visual-studio-code"
    ];

    masApps = {
      # Add Mac App Store apps here
      # Example: "1Password" = 1333542190;
    };
  };

  # User configuration
  users.users.my-user = {
    home = "/Users/my-user";
    description = "My User";
    shell = pkgs.zsh;
  };

  # Programs
  programs.zsh.enable = true;

  # Security - Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;
}
