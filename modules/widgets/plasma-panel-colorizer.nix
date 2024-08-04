{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      example = true;
      inherit description;
    };

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (plasma-panel-colorizer widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  convertColorList = colors:
    if colors == null
    then null
    else builtins.concatStringsSep " " colors;
in
{
  plasmaPanelColorizer = {
    description = "Fully-featured widget to bring Latte-Dock and WM status bar customization features to the default KDE Plasma panel";

    opts = {
      general = {
        enable = mkBoolOption "Whether to enable the widget";
        hideWidget = mkBoolOption "Whether to hide the widget";
      };
      presetAutoLoading = {
        normal = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Normal preset";
          description = "Preset to load when panel is on 'normal' state";
        };
        floating = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Floating preset";
          description = "Preset to load when panel is on 'floating' state";
        };
        touchingWindow = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Touching window preset";
          description = "Preset to load when panel is on 'touching window' state";
        };
        maximized = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Maximized preset";
          description = "Preset to load when panel is on 'maximized' state";
        };
      };
      widgetBackground = {
        enable = mkBoolOption "Whether to enable the widget background configuration";
        colorMode = {
          mode =
            let
              enumVals = [ "static" "animated" ];
            in
            mkOption {
              type = types.nullOr (types.enum enumVals);
              default = null;
              example = "static";
              description = "The color mode to use for the widget background";
              apply = getIndexFromEnum enumVals;
            };
          animationInterval = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 3000;
            description = "The interval in milliseconds between each color change";
          };
          animationSmoothing = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 800;
            description = "The time in milliseconds it takes to transition between colors";
          };
        };
        colors = {
          source =
            let
              enumVals = [
                "custom"
                "system"
                "customList"
                "random"
              ];
            in
            mkOption {
              type = types.nullOr (types.enum enumVals);
              default = null;
              example = "custom";
              description = "The source of the colors to use for the widget background";
              apply = getIndexFromEnum enumVals;
            };
          customColor = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#ff0000";
            description = "The custom color to use for the widget background";
          };
          system = {
            color =
              let
                enumVals = [
                  "text"
                  "disabledText"
                  "highlightedText"
                  "activeText"
                  "link"
                  "visitedLink"
                  "negativeText"
                  "neutralText"
                  "positiveText"
                  "background"
                  "highlight"
                  "activeBackground"
                  "linkBackground"
                  "visitedLinkBackground"
                  "negativeBackground"
                  "neutralBackground"
                  "positiveBackground"
                  "alternateBackground"
                  "focus"
                  "hover"
                ];
              in
              mkOption {
                type = types.nullOr (types.enum enumVals);
                default = null;
                example = "text";
                description = "The system color to use for the widget background";
                apply = getIndexFromEnum enumVals;
              };
            colorSet =
              let
                enumVals = [
                  "view"
                  "window"
                  "button"
                  "selection"
                  "tooltip"
                  "complementary"
                  "header"
                ];
              in
              mkOption {
                type = types.nullOr (types.enum enumVals);
                default = null;
                example = "view";
                description = "The system color variant to use for the widget background";
                apply = getIndexFromEnum enumVals;
              };
          };
          customColorList = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            example = [ "#ff0000" "#00ff00" "#0000ff" ];
            description = "The list of custom colors to use for the widget background";
            apply = convertColorList;
          };
          contrastCorrection = {
            enable = mkBoolOption "Whether to enable contrast correction for the widget background";
            saturation = {
              enable = mkBoolOption "Whether to enable saturation correction for the widget background";
              value = mkOption {
                type = types.nullOr (types.numbers.between 0 1);
                default = null;
                example = 0.5;
                description = "The value to use for the saturation correction";
              };
            };
            lightness = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 0.5;
              description = "The value to use for the lightness correction";
            };
          };
        };
        shape = {
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = "The opacity to use for the widget background";
          };
          radius = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The radius to use for the widget background";
          };
          line = {
            enable = mkBoolOption "Whether to enable the line for the widget background";
            position =
              let enumVals = [ "top" "bottom" "left" "right" ];
              in mkOption {
                type = types.nullOr (types.enum enumVals);
                default = null;
                example = "top";
                description = "The position to use for the line of the widget background";
                apply = getIndexFromEnum enumVals;
              };
            width = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The width to use for the line of the widget background";
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The X offset to use for the line of the widget background";
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The Y offset to use for the line of the widget background";
            };
          };
          outline = {
            colorSource =
              let
                enumVals = [
                  "custom"
                  "system"
                ];
              in
              mkOption {
                type = types.nullOr (types.enum enumVals);
                default = null;
                example = "custom";
                description = "The source of the color to use for the outline of the widget background";
                apply = getIndexFromEnum enumVals;
              };
            customColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#ff0000";
              description = "The custom color to use for the outline of the widget background";
            };
            system = {
              color =
                let
                  enumVals = [
                    "text"
                    "disabledText"
                    "highlightedText"
                    "activeText"
                    "link"
                    "visitedLink"
                    "negativeText"
                    "neutralText"
                    "positiveText"
                    "background"
                    "highlight"
                    "activeBackground"
                    "linkBackground"
                    "visitedLinkBackground"
                    "negativeBackground"
                    "neutralBackground"
                    "positiveBackground"
                    "alternateBackground"
                    "focus"
                    "hover"
                  ];
                in
                mkOption {
                  type = types.nullOr (types.enum enumVals);
                  default = null;
                  example = "text";
                  description = "The system color to use for the outline of the widget background";
                  apply = getIndexFromEnum enumVals;
                };
              colorSet =
                let
                  enumVals = [
                    "view"
                    "window"
                    "button"
                    "selection"
                    "tooltip"
                    "complementary"
                    "header"
                  ];
                in
                mkOption {
                  type = types.nullOr (types.enum enumVals);
                  default = null;
                  example = "view";
                  description = "The system color variant to use for the outline of the widget background";
                  apply = getIndexFromEnum enumVals;
                };
            };
            opacity = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 0.5;
              description = "The opacity to use for the outline of the widget background";
            };
            width = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The width to use for the outline of the widget background";
            };
          };
          shadow = {
            color = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#7f000000";
              description = "The color to use for the shadow of the widget background";
            };
            size = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The size to use for the shadow of the widget background";
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The X offset to use for the shadow of the widget background";
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The Y offset to use for the shadow of the widget background";
            };
          };
        };
      };
      settings = mkOption {
        type = with types; nullOr (attrsOf (attrsOf (either (oneOf [ bool float int str ]) (listOf (oneOf [ bool float int str ])))));
        default = null;
        example = {
          General = {
            isEnabled = true;
          };
        };
        description = ''
          Extra configuration for the widget options.

          See available options at https://github.com/luisbocanegra/plasma-panel-colorizer/blob/main/package/contents/config/main.xml
        '';
        apply = settings:
          if settings == null
          then { }
          else settings;
      };
    };
    convert =
      { general
      , presetAutoLoading
      , widgetBackground
      , settings
      }: {
        name = "luisbocanegra.panel.colorizer";
        config =
          lib.recursiveUpdate
            {
              General = lib.filterAttrs (_: v: v != null) {
                # General options
                isEnabled = general.enable;
                hideWidget = general.hideWidget;

                # Preset autoloading
                normalPreset = presetAutoLoading.normal;
                floatingPreset = presetAutoLoading.floating;
                touchingWindowPreset = presetAutoLoading.touchingWindow;
                maximizedPreset = presetAutoLoading.maximized;

                # Widget background options
                widgetBgEnabled = widgetBackground.enable;

                # Widget background options > Color mode
                mode = widgetBackground.colorMode.mode; # Color mode
                rainbowInterval = widgetBackground.colorMode.animationInterval;
                rainbowTransition = widgetBackground.colorMode.animationSmoothing;

                # Widget background options > Colors
                colorMode = widgetBackground.colors.source;
                singleColor = widgetBackground.colors.customColor; # Custom
                colorModeTheme = widgetBackground.colors.system.color; # System
                colorModeThemeVariant = widgetBackground.colors.system.colorSet; # System variant
                customColors = widgetBackground.colors.customColorList; # Custom list
                bgContrastFixEnabled = widgetBackground.colors.contrastCorrection.enable;
                bgSaturationEnabled = widgetBackground.colors.contrastCorrection.saturation.enable;
                bgSaturation = widgetBackground.colors.contrastCorrection.saturation.value;
                bgLightness = widgetBackground.colors.contrastCorrection.lightness;

                # Widget background options > Shape
                opacity = widgetBackground.shape.opacity;
                radius = widgetBackground.shape.radius;
                bgLineModeEnabled = widgetBackground.shape.line.enable;
                bgLinePosition = widgetBackground.shape.line.position;
                bgLineWidth = widgetBackground.shape.line.width;
                bgLineXOffset = widgetBackground.shape.line.horizontalOffset;
                bgLineYOffset = widgetBackground.shape.line.verticalOffset;

                # Widget background options > Shape > Outline
                widgetOutlineColorMode = widgetBackground.shape.outline.colorSource;
                widgetOutlineColor = widgetBackground.shape.outline.customColor;
                widgetOutlineColorModeTheme = widgetBackground.shape.outline.system.color;
                widgetOutlineColorModeThemeVariant = widgetBackground.shape.outline.system.colorSet;
                widgetOutlineOpacity = widgetBackground.shape.outline.opacity;
                widgetOutlineWidth = widgetBackground.shape.outline.width;

                # Widget background options > Shape > Shadow
                widgetShadowColor = widgetBackground.shape.shadow.color;
                widgetShadowSize = widgetBackground.shape.shadow.size;
                widgetShadowX = widgetBackground.shape.shadow.horizontalOffset;
                widgetShadowY = widgetBackground.shape.shadow.verticalOffset;
              };
            }
            settings;
      };
  };
}
