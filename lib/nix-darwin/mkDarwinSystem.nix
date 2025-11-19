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
