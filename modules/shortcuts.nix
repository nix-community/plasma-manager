{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.programs.plasma =
    let
      inherit (import ../lib/types.nix { inherit config lib; }) attrsWith';
      keys = with lib.types; either str (listOf str);
    in
    {

      shortcuts = lib.mkOption {
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
        type = attrsWith' "group" (attrsWith' "action" keys);
      };

      shortcutSchemes = lib.mkOption {
        description = ''
          Per-app shortcut schemes; written to {file}`$XDG_DATA_HOME/<app>/shortcuts/<scheme-name>`.

          The outer key denotes the app, the middle key denotes the name of the
          scheme, the inner key denotes the action to perform, and the value is
          the list of keys that trigger the action.
        '';
        example = {
          konsole.Custom = {
            close-session = "Ctrl+Shift+W";
            close-window = "Ctrl+Shift+Q";
            new-window = "Ctrl+Shift+N";
            new-tab = "Ctrl+Shift+T";
          };
          okular = {
            Regular = {
              go_goto_page = [
                "G"
                "Shift+G"
                "Ctrl+G"
              ];
              first_page = "Home";
              last_page = "End";
            };
            Vim = {
              first_page = "G";
              last_page = "Shift+G";
            };
          };
        };
        default = { };
        type = attrsWith' "app" (attrsWith' "scheme-name" (attrsWith' "action" keys));
        apply = lib.mapAttrsRecursive (_: v: if lib.isString v then [ v ] else v);
      };

    };

  config =
    let
      cfg = config.programs.plasma;

      # Convert one shortcut into a settings attribute set.
      mkGlobalShortcutFor =
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

      mkGlobalShortcuts = lib.mapAttrs (group: lib.mapAttrs (mkGlobalShortcutFor group));

      xml = pkgs.formats.xml { };

      mkShortcutSchemeFor =
        let
          mkAction = name: keys: {
            "@name" = name;
            "@shortcut" = lib.concatStringsSep "; " keys;
          };
        in
        app: scheme: {
          gui = {
            "@name" = app;
            "@version" = "1";
            ActionProperties.Action = lib.mapAttrsToList mkAction scheme;
          };
        };
    in
    lib.mkIf cfg.enable {
      programs.plasma.configFile."kglobalshortcutsrc" = mkGlobalShortcuts cfg.shortcuts;

      xdg.dataFile = lib.concatMapAttrs (
        app:
        lib.mapAttrs' (
          name: scheme: {
            name = "${app}/shortcuts/${name}";
            value.source = xml.generate "shortcuts-${app}-${name}" (mkShortcutSchemeFor app scheme);
          }
        )
      ) cfg.shortcutSchemes;
    };
}
