# nix-modules

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

See [nixos-features](https://github.com/gfmio/nixos-features) for the feature library.
