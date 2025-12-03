{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.darwin-module;
in
{
  options.my.darwin-module = {
    enable = mkEnableOption "my Darwin module example";

    package = mkOption {
      type = types.package;
      default = pkgs.hello;
      description = "Example package to install";
    };

    enableDevTools = mkOption {
      type = types.bool;
      default = false;
      description = "Enable additional development tools";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to install";
    };
  };

  config = mkIf cfg.enable {
    # Install the main package
    environment.systemPackages = [ cfg.package ]
      ++ cfg.extraPackages
      ++ optionals cfg.enableDevTools (with pkgs; [
      # Development tools
      git
      vim
      neovim
      tmux

      # Build tools
      gnumake
      cmake

      # Language tools
      gcc
      python3
      nodejs
    ]);

    # Example: Configure macOS defaults when this module is enabled
    system.defaults.NSGlobalDomain = {
      # Show hidden files in Finder when dev tools are enabled
      AppleShowAllFiles = mkIf cfg.enableDevTools true;
    };

    # Example: Set up environment variables
    environment.variables = {
      MY_DARWIN_MODULE_ENABLED = "1";
    };
  };
}
