#!/usr/bin/env bash

# Setup script for nix-modules repository
# This script sets up the complete repository structure with all necessary files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 Setting up nix-modules repository..."

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p {tests/{unit,integration},templates/{nixos-workstation,darwin-laptop,home-config},overlays,.github/workflows}

# Create helper functions for library
echo "📚 Creating library helper functions..."

# mkNixosSystem helper
cat > lib/nixos/mkNixosSystem.nix << 'EOF'
{ lib, inputs, self }:

{ hostname
, system
, modules ? [ ]
, specialArgs ? { }
}:

inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // { inherit inputs self; };
  modules = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-features.nixosModules.default
    self.nixosModules.default
    {
      networking.hostName = hostname;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    }
  ] ++ modules;
}
EOF

# mkDarwinSystem helper
cat > lib/nix-darwin/mkDarwinSystem.nix << 'EOF'
{ lib, inputs, self }:

{ hostname
, system
, modules ? [ ]
, specialArgs ? { }
}:

inputs.nix-darwin.lib.darwinSystem {
  inherit system;
  specialArgs = specialArgs // { inherit inputs self; };
  modules = [
    inputs.home-manager.darwinModules.home-manager
    # inputs.nix-darwin-features.darwinModules.default
    self.darwinModules.default
    {
      networking.hostName = hostname;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    }
  ] ++ modules;
}
EOF

# mkHome helper
cat > lib/home-manager/mkHome.nix << 'EOF'
{ lib, inputs, self }:

{ username
, homeDirectory
, system
, modules ? [ ]
, extraSpecialArgs ? { }
}:

inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  extraSpecialArgs = extraSpecialArgs // { inherit inputs self; };
  modules = [
    self.homeModules.default
    {
      home = {
        inherit username homeDirectory;
        stateVersion = "24.11";
      };
    }
  ] ++ modules;
}
EOF

echo "✅ Library helpers created"

# Create overlays
echo "🎨 Creating overlays..."
cat > overlays/default.nix << 'EOF'
{ inputs }:

final: prev: {
  # Add custom packages and overrides here
}
EOF

echo "✅ Overlays created"

echo ""
echo "✅ Repository setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run: nix flake update"
echo "  2. Run: nix flake check"
echo "  3. Run: nix develop"
echo ""
EOF
chmod +x setup-repository.sh
