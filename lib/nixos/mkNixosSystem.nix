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
