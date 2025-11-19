{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.nixos-module;
in
{
  options.my.nixos-module = {
    enable = mkEnableOption "my NixOS module";

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
