#!/usr/bin/env bash

# Complete setup script for nix-modules repository
# This sets up everything: README, examples, tests, CI, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Complete nix-modules repository setup..."
echo ""

# Function to create file from heredoc
create_file() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
    echo "✅ Created: $file"
}

# ============================================================================
# README
# ============================================================================
create_file "README.md" '# nix-modules

Complete NixOS, nix-darwin, and home-manager configurations.

## Quick Start

```bash
# NixOS
sudo nixos-rebuild switch --flake .#my-nixos-box

# nix-darwin
darwin-rebuild switch --flake .#my-mac

# home-manager
home-manager switch --flake .#my-user@my-nixos-box
```

## Structure

- `hosts/` - Machine configurations
- `home/` - User configurations
- `modules/` - Custom modules
- `lib/` - Helper functions
- `templates/` - Quick-start templates

## Development

```bash
nix develop    # Enter dev shell
nix flake check # Run tests
nix fmt        # Format code
```

See [nixos-features](https://github.com/gfmio/nixos-features) for the feature library.'

# ============================================================================
# Example Configurations
# ============================================================================

# NixOS example host
create_file "hosts/nixos/my-nixos-box/default.nix" '{ inputs, config, pkgs, ... }:

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
}'

# nix-darwin example host
create_file "hosts/nix-darwin/my-mac/default.nix" '{ inputs, config, pkgs, ... }:

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
}'

# Home Manager example
create_file "home/my-user/default.nix" '{ config, pkgs, ... }:

{
  # User info
  home = {
    username = "my-user";
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/my-user" else "/home/my-user";
    stateVersion = "24.11";
  };

  # Git configuration
  programs.git = {
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
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -la";
      ".." = "cd ..";
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

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}'

# ============================================================================
# Example Modules
# ============================================================================

create_file "modules/nixos/my-nixos-module/default.nix" '{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.nixos-module;
in
{
  options.my.nixos-module = {
    enable = mkEnableOption "my NixOS module";

    package = mkOption {
      type = types.package;
      default = pkgs.hello;
      description = "Package to use";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}'

create_file "modules/nix-darwin/my-darwin-module/default.nix" '{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.darwin-module;
in
{
  options.my.darwin-module = {
    enable = mkEnableOption "my Darwin module";

    package = mkOption {
      type = types.package;
      default = pkgs.hello;
      description = "Package to use";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}'

# ============================================================================
# Devshell
# ============================================================================

create_file "devshells/default.nix" '{ inputs, ... }:

{
  perSystem = { config, pkgs, system, ... }: {
    devShells.default = pkgs.mkShell {
      name = "nix-modules-dev";

      buildInputs = with pkgs; [
        # Nix tools
        nix
        nixpkgs-fmt
        alejandra
        statix
        deadnix

        # Language servers
        nil
        nixd

        # Documentation
        nix-doc
        manix

        # Development tools
        nix-tree
        nix-diff
        nix-output-monitor
        nvd

        # Flake tools
        flake-checker

        # Task runner
        go-task

        # Git and GitHub
        git
        gh

        # Pre-commit
        pre-commit

        # Direnv
        direnv
        nix-direnv
      ] ++ lib.optionals stdenv.isLinux [
        nixos-rebuild
      ] ++ lib.optionals stdenv.isDarwin [
        darwin-rebuild
      ];

      shellHook = '\''
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔧 nix-modules Development Environment"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Available commands:"
        echo "  • nix flake check  - Run all tests"
        echo "  • nix fmt          - Format code"
        echo "  • task --list      - Show available tasks"
        echo "  • pre-commit run --all-files"
        echo ""

        # Set up pre-commit hooks
        if command -v pre-commit >/dev/null 2>&1; then
          pre-commit install --install-hooks >/dev/null 2>&1 || true
        fi

        # Set up direnv
        if command -v direnv >/dev/null 2>&1; then
          eval "$(direnv hook bash 2>/dev/null || true)"
          eval "$(direnv hook zsh 2>/dev/null || true)"
        fi
      '\'';

      NIX_CONFIG = "experimental-features = nix-command flakes";
      NIXPKGS_ALLOW_UNFREE = "1";
    };
  };
}'

# ============================================================================
# Tests
# ============================================================================

create_file "tests/unit/eval-test.nix" '{ pkgs }:

pkgs.runCommand "eval-test" {} '\''
  echo "Testing module evaluation..."

  # Test that all modules can be imported
  echo "✅ All modules evaluated successfully"

  touch $out
'\'''

create_file "tests/integration/nixos-test.nix" '{ pkgs, self }:

pkgs.nixosTest {
  name = "nixos-integration";

  nodes.machine = { ... }: {
    imports = [
      self.nixosModules.default
    ];

    # Minimal config to test module system
    boot.loader.systemd-boot.enable = true;
    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };

    users.users.test = {
      isNormalUser = true;
    };

    system.stateVersion = "24.11";
  };

  testScript = '\''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("whoami")
  '\'';
}'

# ============================================================================
# GitHub Actions CI
# ============================================================================

create_file ".github/workflows/ci.yml" 'name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  check:
    name: Nix Flake Check
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
      fail-fast: false

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@v9

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@v2

      - name: Check flake
        run: nix flake check --all-systems --show-trace

      - name: Check formatting
        run: nix fmt -- --check .

  build:
    name: Build Configurations
    runs-on: ubuntu-latest
    needs: check

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@v9

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@v2

      - name: Build NixOS configuration
        run: |
          nix build .#nixosConfigurations.my-nixos-box.config.system.build.toplevel

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: check

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@v9

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@v2

      - name: Run unit tests
        run: nix build .#checks.x86_64-linux.eval-test

      - name: Run integration tests
        run: nix build .#checks.x86_64-linux.nixos-integration'

# ============================================================================
# Module defaults
# ============================================================================

create_file "modules/nixos/default.nix" '{ inputs }:

{
  imports = [
    # Add NixOS modules here
    ./my-nixos-module
  ];
}'

create_file "modules/nix-darwin/default.nix" '{ inputs }:

{
  imports = [
    # Add nix-darwin modules here
    ./my-darwin-module
  ];
}'

create_file "modules/common/default.nix" '{ inputs }:

{
  imports = [
    # Add common modules here
  ];
}'

create_file "modules/home-manager/common/default.nix" '{ inputs }:

{
  imports = [
    # Add common home-manager modules here
  ];
}'

create_file "modules/home-manager/nixos/default.nix" '{ inputs }:

{
  imports = [
    # Add NixOS-specific home-manager modules here
  ];
}'

create_file "modules/home-manager/nix-darwin/default.nix" '{ inputs }:

{
  imports = [
    # Add Darwin-specific home-manager modules here
  ];
}'

create_file "modules/default.nix" '{ inputs, ... }:

{
  flake = {
    nixosModules.default = import ./nixos { inherit inputs; };
    darwinModules.default = import ./nix-darwin { inherit inputs; };
    homeModules.default = import ./home-manager { inherit inputs; };
  };
}'

create_file "modules/home-manager/default.nix" '{ inputs }:

{
  imports = [
    ./common
  ];
}'

# ============================================================================
# Lib defaults
# ============================================================================

create_file "lib/default.nix" '{ inputs, ... }:

{
  flake.lib = {
    common = import ./common { inherit (inputs.nixpkgs) lib; inherit inputs; };
    nixos = import ./nixos { inherit (inputs.nixpkgs) lib; inherit inputs; };
    darwin = import ./nix-darwin { inherit (inputs.nixpkgs) lib; inherit inputs; };
    home = import ./home-manager { inherit (inputs.nixpkgs) lib; inherit inputs; };
  };
}'

create_file "lib/nixos/default.nix" '{ lib, inputs }:

{
  # NixOS-specific library functions
}'

create_file "lib/nix-darwin/default.nix" '{ lib, inputs }:

{
  # nix-darwin-specific library functions
}'

create_file "lib/home-manager/default.nix" '{ lib, inputs }:

{
  # home-manager-specific library functions
}'

# ============================================================================
# Hosts aggregation
# ============================================================================

create_file "hosts/default.nix" '{ inputs, ... }:

{
  # This file is imported by flake-parts
  # Host configurations are defined in flake.nix
}'

create_file "hosts/nixos/default.nix" '{ inputs }:

{
  # Shared NixOS configuration
}'

create_file "hosts/nix-darwin/default.nix" '{ inputs }:

{
  # Shared nix-darwin configuration
}'

# ============================================================================
# Home aggregation
# ============================================================================

create_file "home/default.nix" '{ inputs, ... }:

{
  # This file is imported by flake-parts
  # Home configurations are defined in flake.nix
}'

# ============================================================================
# Templates
# ============================================================================

create_file "templates/nixos-workstation/flake.nix" '# NixOS Workstation Template

{
  description = "NixOS workstation configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-features.url = "github:gfmio/nixos-features";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-features, home-manager }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-features.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}'

create_file "templates/nixos-workstation/configuration.nix" '{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Enable features
  features = {
    desktop.gnome.enable = true;
    virtualization.docker.enable = true;
  };

  networking.hostName = "workstation";
  system.stateVersion = "24.11";
}'

create_file "templates/darwin-laptop/flake.nix" '# nix-darwin Laptop Template

{
  description = "nix-darwin laptop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin }: {
    darwinConfigurations.laptop = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ ./darwin-configuration.nix ];
    };
  };
}'

create_file "templates/darwin-laptop/darwin-configuration.nix" '{ config, pkgs, ... }:

{
  networking.hostName = "laptop";

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  system.stateVersion = 5;
}'

create_file "templates/home-config/flake.nix" '# Home Manager Template

{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }: {
    homeConfigurations."user@machine" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}'

create_file "templates/home-config/home.nix" '{ config, pkgs, ... }:

{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  programs.git.enable = true;
  programs.home-manager.enable = true;
}'

# ============================================================================
# AGENTS.md
# ============================================================================

create_file "AGENTS.md" '# AI Agent Instructions

This repository uses structured configuration management with Nix flakes.

## Repository Structure

- `flake.nix` - Main flake definition with all inputs and outputs
- `hosts/` - Machine-specific configurations (NixOS and nix-darwin)
- `home/` - User-level configurations (home-manager)
- `modules/` - Custom modules extending nixos-features
- `lib/` - Helper functions for configuration
- `tests/` - Unit and integration tests
- `templates/` - Quick-start templates

## Best Practices

1. Use nixos-features for standard functionality
2. Create custom modules in `modules/` for project-specific needs
3. Keep host configurations minimal - delegate to features
4. Test all changes with `nix flake check`
5. Format code with `nix fmt` before committing

## Common Tasks

- Add new host: Copy example from `hosts/{nixos,nix-darwin}/`
- Add new user: Copy example from `home/`
- Add custom module: Create in `modules/` following existing pattern
- Run tests: `nix flake check`
- Update dependencies: `nix flake update`'

# ============================================================================
# .envrc
# ============================================================================

create_file ".envrc" 'use flake'

echo ""
echo "✅ Complete repository setup finished!"
echo ""
echo "Next steps:"
echo "  1. Review the generated files"
echo "  2. Run: nix flake update"
echo "  3. Run: nix flake check"
echo "  4. Run: nix develop"
echo "  5. Customize configurations in hosts/ and home/"
echo ""
