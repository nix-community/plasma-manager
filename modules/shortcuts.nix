# Global keyboard shortcuts:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;

  # Convert one shortcut into a settings attribute set.
  shortcutToConfigValue =
    group: _action: skey:
    let
      # Keys are expected to be a list:
      keys =
        if !builtins.isList skey then
          [ skey ]
        else if skey == [ ] then
          [ "none" ]
        else
          skey;

      # Don't allow un-escaped commas:
      escape = lib.escape [ "," ];
      keysStr = builtins.concatStringsSep "\t" (map escape keys);
    in

    # If the shortcut is not in the "services" group, we have to sanitize it.
    if lib.hasPrefix "services/" group then
      keysStr
    else
      lib.concatStringsSep "," [
        keysStr
        "" # List of default keys, not needed.
        "" # Display string, not needed.
      ];

  shortcutsToSettings = lib.mapAttrs (group: lib.mapAttrs (shortcutToConfigValue group));
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
