{ lib, widgets, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  mkBoolOption =
    description:
    mkOption {
      type = with types; nullOr bool;
      default = null;
      inherit description;
    };
in
{
  systemTray = {
    description = "A system tray of other widgets/plasmoids";

    opts = (
      { options, ... }:
      {
        # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/systemtray/package/contents/config/main.xml for the accepted raw options.

        position = mkOption {
          type = positionType;
          example = {
            horizontal = 250;
            vertical = 50;
          };
          description = "The position of the widget. (Only for desktop widget)";
        };
        size = mkOption {
          type = sizeType;
          example = {
            width = 500;
            height = 500;
          };
          description = "The size of the widget. (Only for desktop widget)";
        };
        pin = mkBoolOption "Whether the popup should remain open when another window is activated.";

        icons = {
          spacing =
            let
              enum = [
                "small"
                "medium"
                "large"
              ];
            in
            mkOption {
              type = types.nullOr (types.either (types.enum enum) types.ints.positive);
              default = null;
              description = ''
                The spacing between icons.

                Could be an integer unit, or "small" (1 unit), "medium" (2 units) or "large" (6 units).
              '';
              apply =
                spacing:
                (
                  if (spacing == null) then
                    null
                  else
                    (
                      if builtins.isInt spacing then
                        spacing
                      else
                        builtins.elemAt
                          [
                            1
                            2
                            6
                          ]
                          (
                            lib.lists.findFirstIndex (
                              x: x == spacing
                            ) (throw "systemTray: nonexistent spacing ${spacing}! This is a bug!") enum
                          )
                    )
                );
            };
          scaleToFit = mkBoolOption ''
            Whether to automatically scale System Tray icons to fix the available thickness of the panel.

            If false, tray icons will be capped at the smallMedium size (22px) and become a two-row/column
            layout when the panel is thick.
          '';
        };

        items = {
          showAll = mkBoolOption "If true, all system tray entries will always be in the main bar, outside the popup.";

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
            example = [ "org.kde.plasma.battery" ];
            description = ''
              List of extra widgets that are explicitly enabled in the system tray.

              Expects a list of plasmoid plugin IDs.
            '';
          };

          configs = mkOption {
            # The type here is deliberately NOT modelled exactly correctly,
            # to allow the apply function to provide better errors with the richer option and type system.
            type = types.attrsOf (types.attrsOf types.anything);
            default = { };
            example = {
              # Example of a widget-specific config
              battery.showPercentage = true;
              keyboardLayout.displayStyle = "label";

              # Example of raw config for an untyped widget
              "org.kde.plasma.devicenotifier".config.General = {
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

            # You might be asking yourself... WTH is this?
            # Simply put, this thing allows us to apply the same defaults as defined by the options,
            # Instead of forcing downstream converters to provide defaults to everything *again*.
            # The way to do this is kind of cursed and honestly it might be easier if `lib.evalOptionValue`
            # is not recommended for public use. Oh well.
            apply = lib.mapAttrsToList (
              name: config:
              let
                isKnownWidget = widgets.isKnownWidget name;
                # Raw widgets aren't wrapped in an extra attrset layer, unlike known ones
                # We wrap them back up to ensure the path is accurate
                loc = options.items.configs.loc ++ lib.optional (!isKnownWidget) name;
              in
              widgets.convert
                (lib.mergeDefinitions loc widgets.type [
                  {
                    file = builtins.head options.items.configs.files;
                    # Looks a bit funny, does the job just right.
                    value = if isKnownWidget then { ${name} = config; } else config // { inherit name; };
                  }
                ]).mergedValue
            );
          };
        };
        settings = mkOption {
          type = configValueType;
          default = null;
          description = "Extra configuration options for the widget.";
          apply = settings: if settings == null then { } else settings;
        };
      }
    );

    convert =
      {
        pin,
        icons,
        items,
        settings,
        ...
      }:
      let
        sets = {
          General = lib.filterAttrs (_: v: v != null) {
            inherit pin;
            extraItems = items.extra;
            hiddenItems = items.hidden;
            shownItems = items.shown;
            showAllItems = items.showAll;

            scaleIconsToFit = icons.scaleToFit;
            iconSpacing = icons.spacing;
          };
        };
        mergedSettings = lib.recursiveUpdate sets settings;
      in
      {
        name = "org.kde.plasma.systemtray";
        extraConfig = ''
          (widget) => {
            const tray = desktopById(widget.readConfig("SystrayContainmentId"));
            if (!tray) return; // if somehow the containment doesn't exist

            ${widgets.lib.setWidgetSettings "tray" mergedSettings}
            ${widgets.lib.addWidgetStmts "tray" "trayWidgets" items.configs}
          }
        '';
      };
  };
}
