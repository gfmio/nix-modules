# AI Agent Instructions

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
- Update dependencies: `nix flake update`
