{ inputs, self, ... }:

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
