# Global keyboard shortcuts:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;

  # Convert one shortcut into a settings attribute set.
  shortcutToNameValuePair = action: skey:
    let
      # Keys are expected to be a list:
      keys =
        if builtins.isList skey
        then (if builtins.length skey == 0 then [ "none" ] else skey)
        else [ skey ];

      # Don't allow un-escaped commas:
      escape = lib.escape [ "," ];
    in
    {
      name = action;
      value = lib.concatStringsSep "," [
        (lib.concatStringsSep "\t" (map escape keys))
        "" # List of default keys, not needed.
        "" # Display string, not needed.
      ];
    };

  shortcutsToSettings = groups:
    lib.mapAttrs (_group: lib.mapAttrs' shortcutToNameValuePair) groups;

in
{
  options.programs.plasma.shortcuts = lib.mkOption {
    type = with lib.types; attrsOf (attrsOf (oneOf [ (listOf str) str ]));
    default = { };
    description = ''
      An attribute set where the keys are application groups and the
      values are shortcuts.
    '';
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.files."kglobalshortcutsrc" =
      shortcutsToSettings cfg.shortcuts;
  };
}
