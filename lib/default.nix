{ inputs, ... }:

{
  flake.lib = {
    common = import ./common { inherit (inputs.nixpkgs) lib; inherit inputs; };
    nixos = import ./nixos { inherit (inputs.nixpkgs) lib; inherit inputs; };
    darwin = import ./nix-darwin { inherit (inputs.nixpkgs) lib; inherit inputs; };
    home = import ./home-manager { inherit (inputs.nixpkgs) lib; inherit inputs; };
  };
}
