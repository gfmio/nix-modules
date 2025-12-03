_:

{
  perSystem = { pkgs, lib, ... }: {
    devShells.default = pkgs.mkShell {
      name = "nix-modules-dev";

      buildInputs = with pkgs; [
        # Nix tools
        nix
        nixpkgs-fmt
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

        # Shell utilities
        jq
        yq

        # Testing utilities
        shellcheck
      ] ++ lib.optionals stdenv.isLinux [
        nixos-rebuild
      ];
      # Note: darwin-rebuild comes from nix-darwin and is typically installed system-wide
      # Note: tart should be installed via homebrew on macOS: brew install cirruslabs/cli/tart

      shellHook = ''
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

        # Set up direnv (only for the current shell type)
        if command -v direnv >/dev/null 2>&1; then
          if [ -n "$ZSH_VERSION" ]; then
            eval "$(direnv hook zsh 2>/dev/null || true)"
          elif [ -n "$BASH_VERSION" ]; then
            eval "$(direnv hook bash 2>/dev/null || true)"
          fi
        fi
      '';

      NIX_CONFIG = "experimental-features = nix-command flakes";
      NIXPKGS_ALLOW_UNFREE = "1";
    };
  };
}
