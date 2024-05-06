{lib, widgets, ...}: let
  inherit (lib) mkOption types;

  enums.icons.spacing = ["small" "medium" "large"];
in {
  systemTray = {
    description = "A system tray of other widgets/plasmoids";

    opts = {
      # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/systemtray/package/contents/config/main.xml for the accepted raw options.

      pin = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether the popup should remain open when another window is activated.";
      };

      icons = {
        spacing = mkOption {
          type = types.nullOr (types.either (types.enum enums.icons.spacing) types.ints.positive);
          default = null;
          description = ''
            The spacing between icons.

            Could be an integer unit, or "small" (1 unit), "medium" (2 units) or "large" (6 units).
          '';
        };
        scaleToFit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to automatically scale System Tray icons to fix the available thickness of the panel.

            If false, tray icons will be capped at the smallMedium size (22px) and become a two-row/column
            layout when the panel is thick.
          '';
        };
      };

      items = {
        showAll = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "If true, all system tray entries will always be in the main bar, outside the popup.";
        };

        hidden = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [
            # Plasmoid plugin example
            "org.kde.plasma.brightness"

            # StatusNotifier example
            "org.kde.plasma.addons.katesessions"
          ];
          description = ''
            List of widgets that should be hidden from the main bar, only visible in the popup.

            Expects a list of plasmoid plugin IDs or StatusNotifier IDs.
          '';
        };

        shown = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [
            # Plasmoid plugin example
            "org.kde.plasma.battery"

            # StatusNotifier example
            "org.kde.plasma.addons.katesessions"
          ];
          description = ''
            List of widgets that should be shown in the main bar.

            Expects a list of plasmoid plugin IDs or StatusNotifier IDs.
          '';
        };

        extra = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = ["org.kde.plasma.battery"];
          description = ''
            List of extra widgets that are explicitly enabled in the system tray.

            Expects a list of plasmoid plugin IDs.
          '';
        };

        configs = mkOption {
          # TODO: bother with typing this later
          type = types.attrsOf types.anything;
          default = {};
          example = {
            # Example of a widget-specific config
            battery.enablePercentage = true;

            # Example of raw config for an untyped widget
            "org.kde.plasma.devicenotifier".config = {
              removableDevices = false;
              nonRemovableDevices = true;
            };
          };
          description = ''
            Configurations for each widget in the tray.

            Uses widget-specific configs if the key is a known widget type,
            otherwise uses raw configs that's not specifically checked to be valid,
            or even idiomatic in Nix!
          '';
        };
      };
    };

    convert = {
      pin ? null,
      icons ? {},
      items ? {},
    }: let 
      inherit (widgets.lib) boolToString';

      settings.General = lib.filterAttrs (_: v: v != null) {
        pin = boolToString' pin;
        extraItems = items.extra or null;
        hiddenItems = items.hidden or null;
        shownItems = items.shown or null;
        showAllItems = boolToString' (items.showAll or null);
        scaleItemsToFit = boolToString' (icons.scaleToFit or null);
        iconSpacing = if !(icons ? spacing) then 
          null
        else if builtins.isInt icons.spacing then 
          toString icons.spacing
        else
          widgets.lib.getEnum enums.icons.spacing icons.spacing;
      }; 

      configs' = lib.mapAttrsToList (name: config: 
        if widgets.isKnownWidget name then
          # Looks a bit funny, does the job just right.
          widgets.convert { ${name} = config; }
        else
          { 
            inherit name; 
            config = null; 
            extraConfig = "";
          } // config
      ) items.configs;
    in {
      name = "org.kde.plasma.systemtray";
      extraConfig = ''
        (widget) => {
          const tray = desktopById(widget.readConfig("SystrayContainmentId"));
          if (!tray) return; // if somehow the containment doesn't exist
          
          ${widgets.lib.setWidgetSettings "tray" (builtins.trace items.shown settings)}
          
          ${widgets.lib.addWidgetStmts "tray" "trayWidgets" configs'}
        }
      '';
    };
  };
}
