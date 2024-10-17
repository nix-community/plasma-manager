# Global keyboard shortcuts:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;

  # Checks if the shortcut is in the "service" group, in which case we need to
  # write the values a little differently.
  isService =
    group:
    let
      startString = "services/";
    in
    (builtins.substring 0 (builtins.stringLength startString) group) == startString;

  # Convert one shortcut into a settings attribute set.
  shortcutToConfigValue =
    group: _action: skey:
    let
      # Keys are expected to be a list:
      keys =
        if builtins.isList skey then
          (if ((builtins.length skey) == 0) then [ "none" ] else skey)
        else
          [ skey ];

      # Don't allow un-escaped commas:
      escape = lib.escape [ "," ];
      keysStr = (
        if ((builtins.length keys) == 1) then
          (escape (builtins.head keys))
        else
          builtins.concatStringsSep "\t" (map escape keys)
      );
    in
    (
      if (isService group) then
        keysStr
      else
        (lib.concatStringsSep "," [
          keysStr
          "" # List of default keys, not needed.
          "" # Display string, not needed.
        ])
    );

  shortcutsToSettings =
    groups: lib.mapAttrs (group: attrs: (lib.mapAttrs (shortcutToConfigValue group) attrs)) groups;
in
{
  options.programs.plasma.shortcuts = lib.mkOption {
    type =
      with lib.types;
      attrsOf (
        attrsOf (oneOf [
          (listOf str)
          str
        ])
      );
    default = { };
    description = ''
      An attribute set where the keys are application groups and the
      values are shortcuts.
    '';
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.configFile."kglobalshortcutsrc" = shortcutsToSettings cfg.shortcuts;
  };
}
