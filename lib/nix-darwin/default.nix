{ lib, inputs }:

{
  # Note: mkDarwinSystem is defined separately in flake.nix with self parameter
  # This module contains other darwin-specific helpers

  # Helper to enable nix-darwin-features
  withFeatures = features: {
    imports = [ inputs.nix-darwin-features.darwinModules.default ];
    nix-darwin-features = lib.mkDefault features;
  };

  # Helper to create a user account
  mkUser = { username, uid ? null, description ? "", home ? "/Users/${username}", shell ? null }:
    {
      users.users.${username} = {
        inherit home;
      } // lib.optionalAttrs (uid != null) { inherit uid; }
      // lib.optionalAttrs (description != "") { inherit description; }
      // lib.optionalAttrs (shell != null) { inherit shell; };
    };

  # Helper for homebrew configuration
  mkHomebrew = { enable ? true, taps ? [ ], brews ? [ ], casks ? [ ], masApps ? { } }:
    {
      homebrew = {
        inherit enable taps brews casks;
        masApps = masApps;
        onActivation.cleanup = lib.mkDefault "zap";
      };
    };

  # Helper for macOS system settings
  mkSystemDefaults = defaults:
    {
      system.defaults = defaults;
    };
}
