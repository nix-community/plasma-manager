{ lib, ... }:
let
  inherit (lib) mkOption types;

  widgetMarginRuleType = types.submodule {
    options = {
      widgetId = mkOption {
        type = types.str;
        example = "org.kde.plasma.kickoff";
        description = "Widget id";
      };
      margin = {
        vertical = mkOption {
          type = types.int;
          example = 5;
          description = "Vertical margin value";
        };
        horizontal = mkOption {
          type = types.int;
          example = 5;
          description = "Horizontal margin value";
        };
      };
    };
  };

  convertCustomColors = colors:
    if colors == null
    then null
    else builtins.concatStringsSep " " colors;

  convertWidgets = widgets:
    if widgets == null
    then null
    else "|" + builtins.concatStringsSep "|" widgets;

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (plasma-panel-colorizer widget): Value ${value} isn't present in the enum. This is a bug")
        enum;
in
{
  plasmaPanelColorizer = {
    description = "Fully-featured widget to bring Latte-Dock and WM status bar customization features to the default KDE Plasma panel";

    opts = {
      enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Enable the Plasma Panel Colorizer widget";
      };
      hideWidget = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = ''
          Hide the widget from the panel

          Widget will show when configuring panel or panel edit mode.
        '';
      };
      presetAutoloading = {
        normal = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Normal preset";
          description = ''
            Automatically load normal preset based on panel state.
          '';
        };
        floating = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Floating preset";
          description = ''
            Automatically load floating preset based on panel state.
          '';
        };
        windowTouchingPanel = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Window touching panel preset";
          description = ''
            Automatically load window touching panel preset based on window state.
          '';
        };
        maximizedWindowVisible = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Maximized window visible preset";
          description = ''
            Automatically load maximized window visible preset based on window state.
          '';
        };
      };
      widgetBackground = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Enable widget background";
        };
        mode =
          let enumVals = [ "static" "animated" ];
          in mkOption {
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "static";
            description = ''
              Color mode for the widget background.
            '';
            apply = getIndexFromEnum enumVals;
          };
        animationInterval = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          example = 3000;
          description = ''
            Interval in milliseconds for the widget background animation.
          '';
        };
        animationSmoothing = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          example = 800;
          description = ''
            Smoothing factor for the widget background animation.
          '';
        };
        colorMode =
          let enumVals = [ "custom" "system" "customList" "random" ];
          in mkOption {
            type = types.nullOr types.enum;
            default = null;
            example = "static";
            description = ''
              Color mode for the widget background.
            '';
            apply = getIndexFromEnum enumVals;
          };
        customColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#ff0000";
          description = ''
            Custom color for the widget background.
          '';
        };
        customColorList = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "#ff0000" "#00ff00" "#0000ff" ];
          description = ''
            Custom colors for the widget background.
          '';
          apply = convertCustomColors;
        };
        systemColor =
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
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "text";
            description = ''
              System color for the widget background.
            '';
            apply = getIndexFromEnum enumVals;
          };
        systemColorVariant =
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
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "view";
            description = ''
              System color variant for the widget background.
            '';
            apply = getIndexFromEnum enumVals;
          };
        contrastCorrection = {
          enable = mkOption {
            type = types.nullOr types.bool;
            default = null;
            example = true;
            description = "Enable contrast correction";
          };
          lightness = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 1;
            description = "Lightness value";
          };
          saturation = {
            enable = mkOption {
              type = types.nullOr types.bool;
              default = null;
              example = true;
              description = "Enable saturation";
            };
            value = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 1;
              description = "Saturation value";
            };
          };
        };
        shape = {
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = "Opacity value";
          };
          radius = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "Radius value";
          };
          line = {
            enable = mkOption {
              type = types.nullOr types.bool;
              default = null;
              example = true;
              description = "Enable line mode";
            };
            position =
              let enumVals = [ "top" "bottom" "left" "right" ];
              in mkOption {
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "top";
                description = ''
                  Line position for the widget shape.
                '';
                apply = getIndexFromEnum enumVals;
              };
            width = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "Width value";
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "X offset value";
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = (-1);
              description = "Y offset value";
            };
          };
          outline = {
            colorSource =
              let enumVals = [ "custom" "system" ];
              in mkOption {
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "custom";
                description = ''
                  Color source for the widget outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            customColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#ff0000";
              description = ''
                Custom color for the widget outline.
              '';
            };
            systemColor =
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
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "text";
                description = ''
                  System color for the widget outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            systemColorVariant =
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
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "view";
                description = ''
                  System color variant for the widget outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            opacity = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 0.5;
              description = "Opacity value";
            };
            width = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "Width value";
            };
          };
          shadow = {
            color = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#7fb45c5c";
              description = ''
                Custom color for the widget shadow.
              '';
            };
            size = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "Size value";
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "X offset value";
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = (-1);
              description = "Y offset value";
            };
          };
        };
      };
      textAndIcons = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Enable text and icons";
        };
        mode =
          let enumVals = [ "static" "interval" ];
          in mkOption {
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "static";
            description = ''
              Color mode for the widget text and icons.
            '';
            apply = getIndexFromEnum enumVals;
          };
        interval = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          example = 3000;
          description = ''
            Interval in milliseconds for the widget text and icons.
          '';
        };
        colorMode =
          let enumVals = [ "custom" "system" "customList" "random" "widgetBackground" ];
          in mkOption {
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "random";
            description = ''
              Color mode for the widget text and icons.
            '';
            apply = getIndexFromEnum enumVals;
          };
        customColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#ff0000";
          description = ''
            Custom color for the widget text and icons.
          '';
        };
        customColorList = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "#ff0000" "#00ff00" "#0000ff" ];
          description = ''
            Custom colors for the widget text and icons.
          '';
          apply = convertCustomColors;
        };
        opacity = mkOption {
          type = types.nullOr (types.numbers.between 0 1);
          default = null;
          example = 0.5;
          description = "Opacity value";
        };
        constrastCorrection = {
          enable = mkOption {
            type = types.nullOr types.bool;
            default = null;
            example = true;
            description = "Enable contrast correction";
          };
          lightness = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 1;
            description = "Lightness value";
          };
          saturation = {
            enable = mkOption {
              type = types.nullOr types.bool;
              default = null;
              example = true;
              description = "Enable saturation";
            };
            value = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 1;
              description = "Saturation value";
            };
          };
        };
        shadow = {
          enable = mkOption {
            type = types.nullOr types.bool;
            default = null;
            example = true;
            description = "Enable shadow";
          };
          color = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#7fb45c5c";
            description = ''
              Custom color for the widget shadow.
            '';
          };
          strength = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "Strength value";
          };
          horizontalOffset = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = 5;
            description = "X offset value";
          };
          verticalOffset = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = (-1);
            description = "Y offset value";
          };
        };
        customBadges.fixCustomBadges = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = ''
            Fix unreadable custom badges (e.g. counters) drawn by some widgets.
          '';
        };
        forceIconColorWidgets = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "org.kde.plasma.kickoff" "plasmusic-toolbar" ];
          description = ''
            List of widget ids that should have their icon color forced.
          '';
          apply = convertWidgets;
        };
      };
      panelBackground = {
        hideRealPanelBackground = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = ''
            Hide the real panel background.
          '';
        };
        realPanelOpacity = mkOption {
          type = types.nullOr (types.numbers.between 0 1);
          default = null;
          example = 0.5;
          description = ''
            Opacity value for the real panel background.
          '';
        };
        fixedSizePadding = {
          enable = mkOption {
            type = types.nullOr types.bool;
            default = null;
            example = true;
            description = ''
              Enable fixed size padding.
            '';
          };
          value = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = 5;
            description = ''
              Padding value.
            '';
          };
        };
        customBackground = {
          enable = mkOption {
            type = types.nullOr types.bool;
            default = null;
            example = true;
            description = ''
              Enable custom background.
            '';
          };
          colorSource =
            let enumVals = [ "custom" "system" ];
            in mkOption {
              type = types.nullOr types.enum enumVals;
              default = null;
              example = "custom";
              description = ''
                Color source for the panel custom background.
              '';
              apply = getIndexFromEnum enumVals;
            };
          customColor = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#ff0000";
            description = ''
              Custom color for the panel custom background.
            '';
          };
          systemColor =
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
              type = types.nullOr types.enum enumVals;
              default = null;
              example = "text";
              description = ''
                System color for the panel custom background.
              '';
              apply = getIndexFromEnum enumVals;
            };
          systemColorVariant =
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
              type = types.nullOr types.enum enumVals;
              default = null;
              example = "view";
              description = ''
                System color variant for the panel custom background.
              '';
              apply = getIndexFromEnum enumVals;
            };
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = ''
              Opacity value for the panel custom background.
            '';
          };
          radius = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = 5;
            description = ''
              Radius value for the panel custom background.
            '';
          };
          outline = {
            colorSource =
              let enumVals = [ "custom" "system" ];
              in mkOption {
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "custom";
                description = ''
                  Color source for the panel custom background outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            customColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#ff0000";
              description = ''
                Custom color for the panel custom background outline.
              '';
            };
            systemColor =
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
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "text";
                description = ''
                  System color for the panel custom background outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            systemColorVariant =
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
                type = types.nullOr types.enum enumVals;
                default = null;
                example = "view";
                description = ''
                  System color variant for the panel custom background outline.
                '';
                apply = getIndexFromEnum enumVals;
              };
            opacity = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 0.5;
              description = ''
                Opacity value for the panel custom background outline.
              '';
            };
            width = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = ''
                Width value for the panel custom background outline.
              '';
            };
          };
          shadow = {
            color = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#7fb45c5c";
              description = ''
                Custom color for the panel custom background shadow.
              '';
            };
            size = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = ''
                Size value for the panel custom background shadow.
              '';
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = ''
                X offset value for the panel custom background shadow.
              '';
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = (-1);
              description = ''
                Y offset value for the panel custom background shadow.
              '';
            };
          };
        };
      };
      blacklist = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = ''
            Enable the blacklist.
          '';
        };
        source =
          let enumVals = [ "custom" "system" ];
          in mkOption {
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "custom";
            description = ''
              Source for the blacklist.
            '';
            apply = getIndexFromEnum enumVals;
          };
        systemColor =
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
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "text";
            description = ''
              System color for the blacklist.
            '';
            apply = getIndexFromEnum enumVals;
          };
        systemColorVariant =
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
            type = types.nullOr types.enum enumVals;
            default = null;
            example = "view";
            description = ''
              System color variant for the blacklist.
            '';
            apply = getIndexFromEnum enumVals;
          };
        customColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#ff0000";
          description = ''
            Custom color for the blacklist.
          '';
        };
        blacklistedWidgets = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "org.kde.plasma.kickoff" "org.kde.plasma.kicker" ];
          description = ''
            List of widget ids to blacklist.
          '';
          apply = convertWidgets;
        };
      };
      layout = {
        backgroundMargin = {
          spacing = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = ''
              Spacing value for the background margin.
            '';
          };
          vertical = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = ''
              Vertical value for the background margin.
            '';
            horizontal = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = ''
                Horizontal value for the background margin.
              '';
            };
            widgetMarginRules = mkOption {
              type = types.nullOr (types.listOf widgetMarginRuleType);
              default = null;
              example = [
                {
                  widgetId = "org.kde.plasma.kickoff";
                  margin = {
                    vertical = 5;
                    horizontal = 5;
                  };
                }
                {
                  widgetId = "org.kde.plasma.kicker";
                  margin = {
                    vertical = 5;
                    horizontal = 5;
                  };
                }
              ];
              description = ''
                List of rules to apply margins to specific widgets.
              '';
              apply = rules:
                let
                  widgetToString = widget:
                    "${widget.widgetId},${toString widget.margin.vertical},${toString widget.margin.horizontal}";
                  transformWidgets = widgets:
                    builtins.concatStringsSep "|" (map widgetToString widgets);
                in
                lib.optionalAttrs (rules != null) {
                  marginRules = transformWidgets rules;
                };
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
        apply = settings: if settings == null then { } else settings;
      };
    };
  };
  convert =
    { enable
    , hideWidget
    , presetAutoloading
    , widgetBackground
    , textAndIcons
    , panelBackground
    , blacklist
    , layout
    , settings
    }: {
      name = "luisbocanegra.panel.colorizer";
      config = lib.recursiveUpdate
        {
          General = lib.filterAttrs (_: v: v != null) (
            {
              isEnabled = enable;
              hideWidget = hideWidget;

              normalPreset = presetAutoloading.normal;
              maximizedPreset = presetAutoloading.maximizedWindowVisible;
              floatingPreset = presetAutoloading.floating;
              touchingWindowPreset = presetAutoloading.windowTouchingPanel;

              widgetBgEnabled = widgetBackground.enable;
              mode = widgetBackground.mode;
              rainbowInterval = widgetBackground.animationInterval;
              rainbowTransition = widgetBackground.animationSmoothing;
              colorMode = widgetBackground.colorMode;
              customColors = widgetBackground.customColorList;
              singleColor = widgetBackground.customColor;
              colorModeTheme = widgetBackground.systemColor;
              colorModeThemeVariant = widgetBackground.systemColorVariant;
              bgContrastFixEnabled = widgetBackground.contrastCorrection.enable;
              bgLightness = widgetBackground.contrastCorrection.lightness;
              bgSaturationEnabled = widgetBackground.contrastCorrection.saturation.enable;
              bgSaturation = widgetBackground.contrastCorrection.saturation.value;
              opacity = widgetBackground.shape.opacity;
              radius = widgetBackground.shape.radius;
              bgLineModeEnabled = widgetBackground.shape.line.enable;
              bgLinePosition = widgetBackground.shape.line.position;
              bgLineXOffset = widgetBackground.shape.line.horizontalOffset;
              bgLineYOffset = widgetBackground.shape.line.verticalOffset;

              widgetOutlineColorMode = widgetBackground.shape.outline.colorSource;
              widgetOutlineColor = widgetBackground.shape.outline.customColor;
              widgetOutlineColorModeTheme = widgetBackground.shape.outline.systemColor;
              widgetOutlineColorModeThemeVariant = widgetBackground.shape.outline.systemColorVariant;
              widgetOutlineOpacity = widgetBackground.shape.outline.opacity;
              widgetOutlineWidth = widgetBackground.shape.outline.width;
              widgetShadowColor = widgetBackground.shape.shadow.color;
              widgetShadowSize = widgetBackground.shape.shadow.size;
              widgetShadowX = widgetBackground.shape.shadow.horizontalOffset;
              widgetShadowY = widgetBackground.shape.shadow.verticalOffset;

              fgColorEnabled = textAndIcons.enable;
              fgMode = textAndIcons.mode;
              fgRainbowInterval = textAndIcons.interval;
              fgColorMode = textAndIcons.colorMode;
              fgOpacity = textAndIcons.opacity;
              fgSingleColor = textAndIcons.customColor;
              fgCustomColors = textAndIcons.customColorList;
              fgSaturationEnabled = textAndIcons.constrastCorrection.enable;
              fgSaturation = textAndIcons.constrastCorrection.saturation.value;
              fgLightness = textAndIcons.constrastCorrection.lightness;
              fgShadowColor = textAndIcons.shadow.color;
              fgShadowEnabled = textAndIcons.shadow.enable;
              fgShadowX = textAndIcons.shadow.horizontalOffset;
              fgShadowY = textAndIcons.shadow.verticalOffset;
              fgShadowRadius = textAndIcons.shadow.strength;

              fixCustomBadges = textAndIcons.customBadges.fixCustomBadges;

              hideRealPanelBg = panelBackground.hideRealPanelBackground;
              panelRealBgOpacity = panelBackground.realPanelOpacity;
              enableCustomPadding = panelBackground.fixedSizePadding.enable;
              panelPadding = panelBackground.fixedSizePadding.value;
              panelBgColorMode = panelBackground.customBackground.colorSource;
              panelBgColor = panelBackground.customBackground.customColor;
              panelBgColorModeTheme = panelBackground.customBackground.systemColor;
              panelBgColorModeThemeVariant = panelBackground.customBackground.systemColorVariant;
              panelBgOpacity = panelBackground.customBackground.opacity;
              panelBgRadius = panelBackground.customBackground.radius;
              panelOutlineColorMode = panelBackground.customBackground.outline.colorSource;
              panelOutlineColorModeTheme = panelBackground.customBackground.outline.systemColor;
              panelOutlineColorModeThemeVariant = panelBackground.customBackground.outline.systemColorVariant;
              panelOutlineOpacity = panelBackground.customBackground.outline.opacity;
              panelOutlineWidth = panelBackground.customBackground.outline.width;
              panelOutlineColor = panelBackground.customBackground.outline.customColor;
              panelShadowColor = panelBackground.customBackground.shadow.color;
              panelShadowSize = panelBackground.customBackground.shadow.size;
              panelShadowX = panelBackground.customBackground.shadow.horizontalOffset;
              panelShadowY = panelBackground.customBackground.shadow.verticalOffset;

              blacklist = blacklist.blacklistedWidgets;
              blacklistedFgColor = blacklist.customColor;
              fgBlacklistedColorEnabled = blacklist.enable;
              fgBlacklistedColorMode = blacklist.source;
              fgBlacklistedColorModeTheme = blacklist.systemColor;
              fgBlacklistedColorModeThemeVariant = blacklist.systemColorVariant;

              panelSpacing = layout.backgroundMargin.spacing;
              widgetBgVMargin = layout.backgroundMargin.vertical;
              widgetBgHMargin = layout.backgroundMargin.horizontal;
            }
            // layout.backgroundMargin.widgetMarginRules
          );
        }
        settings;
    };
};
}
