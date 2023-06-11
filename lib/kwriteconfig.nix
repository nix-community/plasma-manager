{ pkgs, lib }:

let

  ##############################################################################
  # Convert a Nix value into a command line argument to kwriteconfig.
  toKdeValue = v:
    if v == null then
      "--delete"
    else if builtins.isString v then
      lib.escapeShellArg v
    else if builtins.isBool v then
      "--type bool " + lib.boolToString v
    else if builtins.isInt v then
      builtins.toString v
    else if builtins.isFloat v then
      builtins.toString v
    else
      builtins.abort ("Unknown value type: " ++ builtins.toString v);

  ##############################################################################
  # Generate a series of shell commands that will update a
  # configuration value.
  #
  # The given file name should be relative to XDG_CONFIG_HOME.
  #
  # The group names are used to generate a nested path to the group
  # containing the settings in the attribute set.
  #
  # The attribute set is the settings and values to set.
  #
  # Type: string -> [string] -> AttrSet -> string
  kWriteConfig = file: groups: attrs:
    lib.concatStringsSep "\n" (lib.mapAttrsToList
      (key: value: ''
        ${pkgs.libsForQt5.kconfig}/bin/kwriteconfig5 \
          --file ${lib.escapeShellArg file} \
          ${lib.concatMapStringsSep " " (g: "--group " + lib.escapeShellArg g) groups} \
          --key ${lib.escapeShellArg key} \
          ${toKdeValue value}
      '')
      attrs);
in
{
  inherit kWriteConfig;
}
