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
    description = ''
      Global shortcuts; written to {file}`$XDG_CONFIG_HOME/kglobalshortcutsrc`.

      The outer key denotes the shortcuts group, the inner key denotes the
      action to perform, and the value is the list of keys that trigger the
      action.
    '';
    example = {
      kmix = {
        "decrease_volume" = [
          "Volume Down"
          "Meta+Down"
        ];
        "increase_volume" = [
          "Volume Up"
          "Meta+Up"
        ];
      };
      kwin = {
        "Switch One Desktop Down" = "Meta+J";
        "Switch One Desktop Up" = "Meta+K";
        "Switch One Desktop to the Left" = "Meta+H";
        "Switch One Desktop to the Right" = "Meta+L";
      };
    };
    default = { };
    type =
      let
        attrsWith' =
          placeholder: elemType:
          lib.types.attrsWith {
            inherit elemType placeholder;
          };
        keys = with lib.types; either str (listOf str);
      in
      attrsWith' "group" (attrsWith' "action" keys);
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.configFile."kglobalshortcutsrc" = shortcutsToSettings cfg.shortcuts;
  };
}
