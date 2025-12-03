{ config, pkgs, ... }:

{
  # User info
  home = {
    username = "my-user";
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/my-user" else "/home/my-user";
    stateVersion = "24.11";
  };

  # Git configuration
  programs = {
    # Let home-manager manage itself
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "My Name";
      userEmail = "me@example.com";

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    # Shell configuration
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "ls -la";
        ".." = "cd ..";
      };
    };
  };

  # Packages
  home.packages = with pkgs; [
    # CLI tools
    ripgrep
    fd
    bat
    eza
    fzf
    jq

    # Development
    git
    gh
    direnv
  ];
}
