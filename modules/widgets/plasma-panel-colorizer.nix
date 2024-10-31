{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  mkBoolOption =
    description:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      example = true;
      inherit description;
    };

  systemColors = [
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

  systemColorSets = [
    "view"
    "window"
    "button"
    "selection"
    "tooltip"
    "complementary"
    "header"
  ];

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (plasma-panel-colorizer widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  convertColorList = colors: if colors == null then null else builtins.concatStringsSep " " colors;

  convertWidgets =
    widgets: if widgets == null then null else "|" + builtins.concatStringsSep "|" widgets;

  convertWidgetMarginRules =
    rules:
    if rules == null then
      null
    else
      let
        widgetToString =
          widget:
          "${widget.widgetId},${toString widget.margin.vertical},${toString widget.margin.horizontal}";
      in
      builtins.concatStringsSep "|" (map widgetToString rules);

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
in
{
  plasmaPanelColorizer = {
    description = "Fully-featured widget to bring Latte-Dock and WM status bar customization features to the default KDE Plasma panel";

    opts = {
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
              enumVals = [
                "static"
                "animated"
              ];
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
            color = mkOption {
              type = types.nullOr (types.enum systemColors);
              default = null;
              example = "text";
              description = "The system color to use for the widget background";
              apply = getIndexFromEnum systemColors;
            };
            colorSet = mkOption {
              type = types.nullOr (types.enum systemColorSets);
              default = null;
              example = "view";
              description = "The system color variant to use for the widget background";
              apply = getIndexFromEnum systemColorSets;
            };
          };
          customColorList = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            example = [
              "#ff0000"
              "#00ff00"
              "#0000ff"
            ];
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
              let
                enumVals = [
                  "top"
                  "bottom"
                  "left"
                  "right"
                ];
              in
              mkOption {
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
              color = mkOption {
                type = types.nullOr (types.enum systemColors);
                default = null;
                example = "text";
                description = "The system color to use for the outline of the widget background";
                apply = getIndexFromEnum systemColors;
              };
              colorSet = mkOption {
                type = types.nullOr (types.enum systemColorSets);
                default = null;
                example = "view";
                description = "The system color variant to use for the outline of the widget background";
                apply = getIndexFromEnum systemColorSets;
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
      textAndIcons = {
        enable = mkBoolOption "Whether to enable the text and icons configuration";
        colorMode = {
          mode =
            let
              enumVals = [
                "static"
                "interval"
              ];
            in
            mkOption {
              type = types.nullOr (types.enum enumVals);
              default = null;
              example = "static";
              description = "The color mode to use for the text and icons";
              apply = getIndexFromEnum enumVals;
            };
          interval = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 3000;
            description = "The interval in milliseconds between each color change";
          };
        };
        colors = {
          source =
            let
              enumVals = [
                "custom"
                "system"
                "widgetBackground"
                "customList"
                "random"
              ];
            in
            mkOption {
              type = types.nullOr (types.enum enumVals);
              default = null;
              example = "custom";
              description = "The source of the colors to use for the text and icons";
              apply = getIndexFromEnum enumVals;
            };
          customColor = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#ff0000";
            description = "The custom color to use for the text and icons";
          };
          system = {
            color = mkOption {
              type = types.nullOr (types.enum systemColors);
              default = null;
              example = "text";
              description = "The system color to use for the text and icons";
              apply = getIndexFromEnum systemColors;
            };
            colorSet = mkOption {
              type = types.nullOr (types.enum systemColorSets);
              default = null;
              example = "view";
              description = "The system color variant to use for the text and icons";
              apply = getIndexFromEnum systemColorSets;
            };
          };
          customColorList = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            example = [
              "#ff0000"
              "#00ff00"
              "#0000ff"
            ];
            description = "The list of custom colors to use for the text and icons";
            apply = convertColorList;
          };
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = "The opacity to use for the text and icons";
          };
          contrastCorrection = {
            enable = mkBoolOption "Whether to enable contrast correction for the text and icons";
            saturation = {
              enable = mkBoolOption "Whether to enable saturation correction for the text and icons";
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
        shadow = {
          enable = mkBoolOption "Whether to enable the shadow for the text and icons";
          color = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#7f000000";
            description = "The color to use for the shadow of the text and icons";
          };
          strength = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The strength to use for the shadow of the text and icons";
          };
          horizontalOffset = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = 5;
            description = "The X offset to use for the shadow of the text and icons";
          };
          verticalOffset = mkOption {
            type = types.nullOr types.int;
            default = null;
            example = 5;
            description = "The Y offset to use for the shadow of the text and icons";
          };
        };
        customBadges = {
          fixCustomBadges = mkBoolOption "Whether to fix custom badges";
        };
        forceIconColor = {
          widgets = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            example = [ "org.kde.plasma.digitalclock" ];
            description = "List of widgets to force icon color";
            apply = convertWidgets;
          };
        };
      };
      panelBackground = {
        originalBackground = {
          hide = mkBoolOption "Whether to hide the original panel background";
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = "The opacity to use for the original panel background";
          };
          fixedSizePadding = {
            enable = mkBoolOption "Whether to enable fixed size padding";
            value = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The value to use for the fixed size padding in pixels";
            };
          };
        };
        customBackground = {
          enable = mkBoolOption "Whether to enable the custom panel background";
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
              description = "The source of the color to use for the custom panel background";
              apply = getIndexFromEnum enumVals;
            };
          customColor = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#ff0000";
            description = "The custom color to use for the custom panel background";
          };
          system = {
            color = mkOption {
              type = types.nullOr (types.enum systemColors);
              default = null;
              example = "text";
              description = "The system color to use for the custom panel background";
              apply = getIndexFromEnum systemColors;
            };
            colorSet = mkOption {
              type = types.nullOr (types.enum systemColorSets);
              default = null;
              example = "view";
              description = "The system color variant to use for the custom panel background";
              apply = getIndexFromEnum systemColorSets;
            };
          };
          opacity = mkOption {
            type = types.nullOr (types.numbers.between 0 1);
            default = null;
            example = 0.5;
            description = "The opacity to use for the custom panel background";
          };
          radius = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The radius to use for the custom panel background";
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
                description = "The source of the color to use for the outline of the custom panel background";
                apply = getIndexFromEnum enumVals;
              };
            customColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#ff0000";
              description = "The custom color to use for the outline of the custom panel background";
            };
            system = {
              color = mkOption {
                type = types.nullOr (types.enum systemColors);
                default = null;
                example = "text";
                description = "The system color to use for the outline of the custom panel background";
                apply = getIndexFromEnum systemColors;
              };
              colorSet = mkOption {
                type = types.nullOr (types.enum systemColorSets);
                default = null;
                example = "view";
                description = "The system color variant to use for the outline of the custom panel background";
                apply = getIndexFromEnum systemColorSets;
              };
            };
            opacity = mkOption {
              type = types.nullOr (types.numbers.between 0 1);
              default = null;
              example = 0.5;
              description = "The opacity to use for the outline of the custom panel background";
            };
            width = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The width to use for the outline of the custom panel background";
            };
          };
          shadow = {
            color = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#7f000000";
              description = "The color to use for the shadow of the custom panel background";
            };
            size = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              example = 5;
              description = "The size to use for the shadow of the custom panel background";
            };
            horizontalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The X offset to use for the shadow of the custom panel background";
            };
            verticalOffset = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 5;
              description = "The Y offset to use for the shadow of the custom panel background";
            };
          };
        };
      };
      blacklist = {
        enable = mkBoolOption "Whether to enable the blacklist";
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
            description = "The source of the color to use for the blacklisted text and icons";
            apply = getIndexFromEnum enumVals;
          };
        customColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#ff0000";
          description = "The custom color to use for the blacklisted text and icons";
        };
        system = {
          color = mkOption {
            type = types.nullOr (types.enum systemColors);
            default = null;
            example = "text";
            description = "The system color to use for the blacklisted text and icons";
            apply = getIndexFromEnum systemColors;
          };
          colorSet = mkOption {
            type = types.nullOr (types.enum systemColorSets);
            default = null;
            example = "view";
            description = "The system color variant to use for the blacklisted text and icons";
            apply = getIndexFromEnum systemColorSets;
          };
        };
        widgets = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "org.kde.plasma.digitalclock" ];
          description = "List of widgets to blacklist, blacklisted widgets will not be colorized";
          apply = convertWidgets;
        };
      };
      layout = {
        enable = mkBoolOption "Whether to enable the layout configuration";
        backgroundMargin = {
          spacing = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The spacing to use for the background margin";
          };
          vertical = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The vertical margin to use for the background margin";
          };
          horizontal = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            example = 5;
            description = "The horizontal margin to use for the background margin";
          };
        };
        widgetMarginRules = mkOption {
          type = types.nullOr (types.listOf widgetMarginRuleType);
          default = null;
          example = [
            {
              widgetId = "org.kde.plasma.kickoff";
              margin = {
                vertical = 1;
                horizontal = 2;
              };
            }
            {
              widgetId = "org.kde.plasma.digitalclock";
              margin = {
                vertical = 2;
                horizontal = 1;
              };
            }
          ];
          description = ''
            List of rules to apply margins to specific widgets

            Define every widget from the panel here.
          '';
          apply = convertWidgetMarginRules;
        };
      };
      settings = mkOption {
        type = configValueType;
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
    convert =
      {
        general,
        presetAutoLoading,
        widgetBackground,
        textAndIcons,
        panelBackground,
        blacklist,
        layout,
        settings,
        ...
      }:
      {
        name = "luisbocanegra.panel.colorizer";
        config = lib.recursiveUpdate {
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

            # Text and icons options
            fgColorEnabled = textAndIcons.enable;

            # Text and icons options > Color mode
            fgMode = textAndIcons.colorMode.mode;
            fgRainbowInterval = textAndIcons.colorMode.interval;

            # Text and icons options > Colors
            fgColorMode = textAndIcons.colors.source;
            fgSingleColor = textAndIcons.colors.customColor;
            fgColorModeTheme = textAndIcons.colors.system.color;
            fgColorModeThemeVariant = textAndIcons.colors.system.colorSet;
            fgCustomColors = textAndIcons.colors.customColorList;
            fgOpacity = textAndIcons.colors.opacity;
            fgContrastFixEnabled = textAndIcons.colors.contrastCorrection.enable;
            fgSaturationEnabled = textAndIcons.colors.contrastCorrection.saturation.enable;
            fgSaturation = textAndIcons.colors.contrastCorrection.saturation.value;
            fgLightness = textAndIcons.colors.contrastCorrection.lightness;

            # Text and icons options > Shadow
            fgShadowEnabled = textAndIcons.shadow.enable;
            fgShadowColor = textAndIcons.shadow.color;
            fgShadowRadius = textAndIcons.shadow.strength;
            fgShadowX = textAndIcons.shadow.horizontalOffset;
            fgShadowY = textAndIcons.shadow.verticalOffset;

            # Text and icons options > Custom badges
            fixCustomBadges = textAndIcons.customBadges.fixCustomBadges;

            # Text and icons options > Force icon color
            forceRecolor = textAndIcons.forceIconColor.widgets;

            # Panel background options > Original background
            hideRealPanelBg = panelBackground.originalBackground.hide;
            panelRealBgOpacity = panelBackground.originalBackground.opacity;
            enableCustomPadding = panelBackground.originalBackground.fixedSizePadding.enable;
            panelPadding = panelBackground.originalBackground.fixedSizePadding.value;

            # Panel background options > Custom background
            panelBgEnabled = panelBackground.customBackground.enable;
            panelBgColorMode = panelBackground.customBackground.colorSource;
            panelBgColor = panelBackground.customBackground.customColor;
            panelBgColorModeTheme = panelBackground.customBackground.system.color;
            panelBgColorModeThemeVariant = panelBackground.customBackground.system.colorSet;
            panelBgOpacity = panelBackground.customBackground.opacity;
            panelBgRadius = panelBackground.customBackground.radius;

            # Panel background options > Custom background > Outline
            panelOutlineColorMode = panelBackground.customBackground.outline.colorSource;
            panelOutlineColor = panelBackground.customBackground.outline.customColor;
            panelOutlineColorModeTheme = panelBackground.customBackground.outline.system.color;
            panelOutlineColorModeThemeVariant = panelBackground.customBackground.outline.system.colorSet;
            panelOutlineOpacity = panelBackground.customBackground.outline.opacity;
            panelOutlineWidth = panelBackground.customBackground.outline.width;

            # Panel background options > Custom background > Shadow
            panelShadowColor = panelBackground.customBackground.shadow.color;
            panelShadowSize = panelBackground.customBackground.shadow.size;
            panelShadowX = panelBackground.customBackground.shadow.horizontalOffset;
            panelShadowY = panelBackground.customBackground.shadow.verticalOffset;

            # Blacklist options
            fgBlacklistedColorEnabled = blacklist.enable;
            fgBlacklistedColorMode = blacklist.colorSource;
            blacklistedFgColor = blacklist.customColor;
            fgBlacklistedColorModeTheme = blacklist.system.color;
            fgBlacklistedColorModeThemeVariant = blacklist.system.colorSet;
            blacklist = blacklist.widgets;

            # Layout options
            layoutEnabled = layout.enable;

            # Layout options > Background margin
            panelSpacing = layout.backgroundMargin.spacing;
            widgetBgHMargin = layout.backgroundMargin.horizontal;
            widgetBgVMargin = layout.backgroundMargin.vertical;

            # Layout options > Widget margin rules
            marginRules = layout.widgetMarginRules;
          };
        } settings;
      };
  };
}
