{
  description = "Complete NixOS, nix-darwin, and home-manager configurations";

  inputs = {
    # Nixpkgs channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Feature libraries (use local paths for development)
    nixos-features = {
      # url = "github:gfmio/nixos-features";
      url = "path:/Users/gfmio/projects/github/gfmio/nixos-features";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin-features (commented out until published)
    # TODO: Uncomment when nix-darwin-features is available
    nix-darwin-features = {
      # url = "github:gfmio/nix-darwin-features";
      url = "path:/Users/gfmio/projects/github/gfmio/nix-darwin-features";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Core infrastructure
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # Platform managers
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Additional useful inputs
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";

    # Development tools
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.pre-commit-hooks.flakeModule
        ./devshells
        ./lib
        ./modules
        ./hosts
        ./home
      ];

      perSystem = { config, pkgs, system, ... }: {
        # Formatter
        formatter = pkgs.nixpkgs-fmt;

        # Pre-commit hooks
        pre-commit = {
          check.enable = true;
          settings = {
            hooks = {
              # Nix formatting
              nixpkgs-fmt.enable = true;

              # Nix linting
              statix.enable = true;
              deadnix.enable = true;

              # General checks
              check-merge-conflicts.enable = true;
              check-added-large-files.enable = true;
              check-toml.enable = true;
              check-yaml.enable = true;
              end-of-file-fixer.enable = true;
              trim-trailing-whitespace.enable = true;

              # Markdown
              markdownlint = {
                enable = true;
                settings.configuration = {
                  MD013 = false; # Line length
                  MD033 = false; # Allow inline HTML
                  MD041 = false; # First line must be h1
                };
              };
            };
          };
        };

        # Checks
        checks = {
          # Format check
          formatting = pkgs.runCommand "check-formatting"
            {
              buildInputs = [ pkgs.nixpkgs-fmt ];
            } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${self}
            touch $out
          '';

          # Statix linting
          statix = pkgs.runCommand "check-statix"
            {
              buildInputs = [ pkgs.statix ];
            } ''
            ${pkgs.statix}/bin/statix check ${self}
            touch $out
          '';

          # Dead code check
          deadnix = pkgs.runCommand "check-deadnix"
            {
              buildInputs = [ pkgs.deadnix ];
            } ''
            ${pkgs.deadnix}/bin/deadnix --fail ${self}
            touch $out
          '';

          # Pre-commit hooks
          pre-commit-check = config.pre-commit.installationScript;
        };
      };

      flake = {
        # Library functions
        lib = {
          # Common utilities
          common = import ./lib/common { inherit (nixpkgs) lib; inherit inputs; };

          # Platform-specific utilities
          nixos = import ./lib/nixos { inherit (nixpkgs) lib; inherit inputs; };
          darwin = import ./lib/nix-darwin { inherit (nixpkgs) lib; inherit inputs; };
          home = import ./lib/home-manager { inherit (nixpkgs) lib; inherit inputs; };

          # Convenience function to create a NixOS system
          mkNixosSystem = import ./lib/nixos/mkNixosSystem.nix {
            inherit (nixpkgs) lib;
            inherit inputs self;
          };

          # Convenience function to create a nix-darwin system
          mkDarwinSystem = import ./lib/nix-darwin/mkDarwinSystem.nix {
            inherit (nixpkgs) lib;
            inherit inputs self;
          };

          # Convenience function to create a home-manager configuration
          mkHome = import ./lib/home-manager/mkHome.nix {
            inherit (nixpkgs) lib;
            inherit inputs self;
          };
        };

        # Export custom modules
        nixosModules = {
          default = import ./modules/nixos { inherit inputs; };
          common = import ./modules/common { inherit inputs; };
        };

        darwinModules = {
          default = import ./modules/nix-darwin { inherit inputs; };
          common = import ./modules/common { inherit inputs; };
        };

        homeModules = {
          default = import ./modules/home-manager { inherit inputs; };
          common = import ./modules/home-manager/common { inherit inputs; };
          nixos = import ./modules/home-manager/nixos { inherit inputs; };
          darwin = import ./modules/home-manager/nix-darwin { inherit inputs; };
        };

        # Host configurations
        nixosConfigurations = {
          my-nixos-box = self.lib.mkNixosSystem {
            hostname = "my-nixos-box";
            system = "x86_64-linux";
            modules = [ ./hosts/nixos/my-nixos-box ];
          };
        };

        darwinConfigurations = {
          my-mac = self.lib.mkDarwinSystem {
            hostname = "my-mac";
            system = "aarch64-darwin";
            modules = [ ./hosts/nix-darwin/my-mac ];
          };
        };

        # Home configurations
        homeConfigurations = {
          "my-user@my-nixos-box" = self.lib.mkHome {
            username = "my-user";
            homeDirectory = "/home/my-user";
            system = "x86_64-linux";
            modules = [ ./home/my-user ];
          };

          "my-user@my-mac" = self.lib.mkHome {
            username = "my-user";
            homeDirectory = "/Users/my-user";
            system = "aarch64-darwin";
            modules = [ ./home/my-user ];
          };
        };

        # Templates for quick starts
        templates = {
          nixos-workstation = {
            path = ./templates/nixos-workstation;
            description = "NixOS workstation with common development features";
            welcomeText = ''
              # NixOS Workstation Template

              This template provides a complete NixOS workstation configuration with:
              - Desktop environment (GNOME/KDE/Hyprland)
              - Development tools (Docker, Git, etc.)
              - Security hardening
              - Hardware support

              Edit `configuration.nix` to customize your system.
            '';
          };

          darwin-laptop = {
            path = ./templates/darwin-laptop;
            description = "nix-darwin laptop configuration with productivity tools";
            welcomeText = ''
              # nix-darwin Laptop Template

              This template provides a complete macOS laptop configuration with:
              - System preferences and tweaks
              - Development tools
              - Homebrew cask integration
              - Productivity apps

              Edit `darwin-configuration.nix` to customize your system.
            '';
          };

          home-config = {
            path = ./templates/home-config;
            description = "Standalone home-manager configuration";
            welcomeText = ''
              # Home Manager Template

              This template provides a cross-platform home-manager configuration with:
              - Shell configuration (zsh, bash, fish)
              - Git and development tools
              - Dotfiles management
              - Application settings

              Edit `home.nix` to customize your environment.
            '';
          };
        };

        # Overlays
        overlays = {
          default = import ./overlays { inherit inputs; };
        };

        # Packages (if any custom packages are added)
        packages = nixpkgs.lib.genAttrs
          (import inputs.systems)
          (system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
            in
            {
              # Add custom packages here
            }
          );
      };
    };
}
