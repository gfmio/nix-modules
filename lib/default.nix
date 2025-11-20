{ inputs, self, ... }:

{
  flake.lib = {
    # Platform-agnostic utilities
    common = import ./common { inherit (inputs.nixpkgs) lib; inherit inputs; };
    nixos = import ./nixos { inherit (inputs.nixpkgs) lib; inherit inputs; };
    darwin = import ./nix-darwin { inherit (inputs.nixpkgs) lib; inherit inputs; };
    home = import ./home-manager { inherit (inputs.nixpkgs) lib; inherit inputs; };

    # Convenience functions that need `self`
    mkNixosSystem = import ./nixos/mkNixosSystem.nix {
      inherit (inputs.nixpkgs) lib;
      inherit inputs self;
    };

    mkDarwinSystem = import ./nix-darwin/mkDarwinSystem.nix {
      inherit (inputs.nixpkgs) lib;
      inherit inputs self;
    };

    mkHome = import ./home-manager/mkHome.nix {
      inherit (inputs.nixpkgs) lib;
      inherit inputs self;
    };
  };
}
