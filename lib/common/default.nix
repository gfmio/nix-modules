/*
  Common, module-type independent library functions
 */

{ lib, ... }:

{
  # This file aggregates all library functions that are not specific to a
  # particular system, module type or similar.

  # Helper to create a simple module that just imports a list of files
  mkModuleFromFiles = files: {
    imports = files;
  };

  # Helper to create an attrset of modules from a directory
  mkModulesFromDir = dir:
    let
      entries = builtins.readDir dir;
      modules = lib.filterAttrs (name: type: type == "directory" || lib.hasSuffix ".nix" name) entries;
    in
    lib.mapAttrs'
      (name: type:
        let
          moduleName = lib.removeSuffix ".nix" name;
          modulePath = if type == "directory" then "${dir}/${name}" else "${dir}/${name}";
        in
        lib.nameValuePair moduleName (import modulePath)
      )
      modules;
}
