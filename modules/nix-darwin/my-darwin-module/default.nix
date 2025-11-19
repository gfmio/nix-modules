{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.darwin-module;
in
{
  options.my.darwin-module = {
    enable = mkEnableOption "my Darwin module";

    package = mkOption {
      type = types.package;
      default = pkgs.hello;
      description = "Package to use";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
