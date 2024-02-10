# Global keyboard shortcuts:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;

  # Convert one shortcut into a settings attribute set.
  shortcutToNameValuePair = _action: skey:
    let
      # Keys are expected to be a list:
      keys =
        if builtins.isList skey
        then
          (if ((builtins.length skey) == 0) then [ "none" ] else skey)
        else [ skey ];

      # Don't allow un-escaped commas:
      escape = lib.escape [ "," ];
    in
    lib.concatStringsSep "," [
      (if ((builtins.length keys) == 1) then (escape (builtins.head keys)) else "\t" + (lib.concatStringsSep "\t" (map escape keys)))
      "" # List of default keys, not needed.
      "" # Display string, not needed.
    ];

  shortcutsToSettings = groups:
    lib.mapAttrs
      (group: attrs:
        (lib.mapAttrs shortcutToNameValuePair attrs) // {
          # Some shortcut groups have a dot in their name so we
          # explicitly set the group nesting to only one level deep:
          configGroupNesting = [ group ];
        })
      groups;
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
    programs.plasma.configFile."kglobalshortcutsrc" =
      shortcutsToSettings cfg.shortcuts;
  };
}
