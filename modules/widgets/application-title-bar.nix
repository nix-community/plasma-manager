{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  elements = [
    "windowCloseButton"
    "windowMinimizeButton"
    "windowMaximizeButton"
    "windowKeepAboveButton"
    "windowKeepBelowButton"
    "windowShadeButton"
    "windowTitle"
    "windowIcon"
    "spacer"
  ];

  horizontalAlignment = [
    "left"
    "right"
    "center"
    "justify"
  ];

  windowTitleSources = [
    "appName"
    "decoration"
    "genericAppName"
    "alwaysUndefined"
  ];

  mkBoolOption =
    description:
    lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      inherit description;
    };

  convertHorizontalAlignment =
    horizontalAlignment:
    let
      mappings = {
        left = 1;
        right = 2;
        center = 4;
        justify = 8;
      };
    in
    if horizontalAlignment == null then
      null
    else
      mappings.${horizontalAlignment} or (throw "Invalid enum value: ${horizontalAlignment}");

  convertVerticalAlignment =
    verticalAlignment:
    let
      mappings = {
        top = 1;
        center = 128;
        bottom = 64;
        baseline = 256;
      };
    in
    if verticalAlignment == null then
      null
    else
      mappings.${verticalAlignment} or (throw "Invalid enum value: ${verticalAlignment}");

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (application-title-bar widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  capitalizeWord =
    word:
    let
      firstLetter = builtins.substring 0 1 word;
      rest = builtins.substring 1 (builtins.stringLength word - 1) word;
    in
    if word == null then null else "${lib.toUpper firstLetter}${rest}";

  fontType = lib.types.submodule {
    options = {
      bold = mkBoolOption "Enable bold text.";
      fit =
        let
          enumVals = [
            "fixedSize"
            "horizontalFit"
            "verticalFit"
            "fit"
          ];
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum enumVals);
          default = null;
          example = "fixedSize";
          description = "The mode of the size of the font.";
          apply = getIndexFromEnum enumVals;
        };
      size = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "The size of the font.";
      };
    };
  };

  marginType = lib.types.submodule {
    options = {
      left = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 10;
        description = "The left margin.";
      };
      right = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 10;
        description = "The right margin.";
      };
      top = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "The top margin.";
      };
      bottom = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "The bottom margin.";
      };
    };
  };

  titleReplacementType = lib.types.submodule {
    options = {
      type =
        let
          enumVals = [
            "string"
            "regexp"
          ];
        in
        lib.mkOption {
          type = lib.types.enum enumVals;
          default = null;
          example = "string";
          description = "The type of the replacement.";
          apply = getIndexFromEnum enumVals;
        };
      originalTitle = lib.mkOption {
        type = lib.types.str;
        example = "Brave Web Browser";
        description = "The original text to replace.";
      };
      newTitle = lib.mkOption {
        type = lib.types.str;
        example = "Brave";
        description = "The new text to replace with.";
      };
    };
  };
in
{
  applicationTitleBar = {
    description = "KDE plasmoid with window title and buttons";

    opts = {
      position = lib.mkOption {
        type = positionType;
        example = {
          horizontal = 100;
          vertical = 300;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = lib.mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 50;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      layout = {
        widgetMargins = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The margins around the widget.";
        };
        spacingBetweenElements = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The spacing between elements.";
        };
        horizontalAlignment = lib.mkOption {
          type = with lib.types; nullOr (enum horizontalAlignment);
          default = null;
          example = "left";
          description = "The horizontal alignment of the widget.";
          apply = convertHorizontalAlignment;
        };
        verticalAlignment = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "top"
              "center"
              "bottom"
              "baseline"
            ]);
          default = null;
          example = "center";
          description = "The vertical alignment of the widget.";
          apply = convertVerticalAlignment;
        };
        showDisabledElements =
          let
            enumVals = [
              "deactivated"
              "hideKeepSpace"
              "hide"
            ];
          in
          lib.mkOption {
            type = with lib.types; nullOr (enum enumVals);
            default = null;
            example = "deactivated";
            description = "How to show the elements when the widget is disabled.";
            apply = getIndexFromEnum enumVals;
          };
        fillFreeSpace = mkBoolOption "Whether the widget should fill the free space on the panel.";
        elements = lib.mkOption {
          type = with lib.types; nullOr (listOf (enum elements));
          default = null;
          example = [ "windowTitle" ];
          description = ''
            The elements to show in the widget.
          '';
        };
      };
      windowControlButtons = {
        iconSource =
          let
            enumVals = [
              "plasma"
              "breeze"
              "aurorae"
              "oxygen"
            ];
          in
          lib.mkOption {
            type = with lib.types; nullOr (enum enumVals);
            default = null;
            example = "plasma";
            description = ''
              The icon source for the control buttons.

              - Plasma: Global icon theme
              - Breeze: Implicit Breeze icons
              - Aurorae: Window decorations theme
              - Oxygen: Implicit Oxygen icons
            '';
            apply = getIndexFromEnum enumVals;
          };
        auroraeTheme = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The Aurorae theme to use for the control buttons.";
        };
        buttonsMargin = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The margin around the buttons.";
        };
        buttonsAspectRatio = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The ratio of button width in percent to 100% of its height. If you need wider buttons, the value should be >100, otherwise less.";
        };
        buttonsAnimationSpeed = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The speed of the buttons animation in milliseconds.";
        };
      };
      windowTitle = {
        minimumWidth = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The minimum width of the window title.";
        };
        maximumWidth = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The maximum width of the window title.";
        };
        font = lib.mkOption {
          type = lib.types.nullOr fontType;
          default = null;
          example = {
            bold = false;
            fit = "FixedSize";
            size = 11;
          };
          description = "The font settings of the window title.";
          apply =
            font:
            lib.optionalAttrs (font != null) {
              windowTitleFontBold = font.bold;
              windowTitleFontSize = font.size;
              windowTitleFontSizeMode = font.fit;
            };
        };
        hideEmptyTitle = mkBoolOption "Whether to hide the window title when it's empty.";
        undefinedWindowTitle = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "Plasma";
          description = "The text to show when the window title is undefined.";
        };
        source = lib.mkOption {
          type = with lib.types; nullOr (enum windowTitleSources);
          default = null;
          example = "appName";
          description = ''
            The source of the window title.

            - appName: The name of the application
            - decoration: The title of the window decoration
            - genericAppName: The generic name of the application
            - alwaysUndefined: Always show the undefined title
          '';
          apply = getIndexFromEnum windowTitleSources;
        };
        margins = lib.mkOption {
          type = lib.types.nullOr marginType;
          default = null;
          example = {
            left = 10;
            right = 10;
            top = 0;
            bottom = 0;
          };
          description = "The margins around the window title.";
          apply =
            margins:
            lib.optionalAttrs (margins != null) {
              windowTitleMarginsLeft = margins.left;
              windowTitleMarginsRight = margins.right;
              windowTitleMarginsTop = margins.top;
              windowTitleMarginsBottom = margins.bottom;
            };
        };
        horizontalAlignment = lib.mkOption {
          type = with lib.types; nullOr (enum horizontalAlignment);
          default = null;
          example = "left";
          description = "The horizontal alignment of the window title.";
          apply = capitalizeWord;
        };
        verticalAlignment =
          let
            enumVals = [
              "top"
              "bottom"
              "center"
            ];
          in
          lib.mkOption {
            type = with lib.types; nullOr (enum enumVals);
            default = null;
            example = "center";
            description = "The vertical alignment of the window title.";
            apply = capitalizeWord;
          };
      };
      overrideForMaximized = {
        enable = mkBoolOption "Whether to override the settings for maximized windows.";
        elements = lib.mkOption {
          type = with lib.types; nullOr (types.listOf (types.enum elements));
          default = null;
          example = [ "windowTitle" ];
          description = ''
            The elements to show in the widget for maximized windows.
          '';
        };
        source = lib.mkOption {
          type = with lib.types; nullOr (enum windowTitleSources);
          default = null;
          example = "appName";
          description = ''
            The source of the window title for maximized windows.

            - appName: The name of the application
            - decoration: The title of the window decoration
            - genericAppName: The generic name of the application
            - alwaysUndefined: Always show the undefined title
          '';
          apply = getIndexFromEnum windowTitleSources;
        };
      };
      behavior = {
        activeTaskSource =
          let
            enumVals = [
              "activeTask"
              "lastActiveTask"
              "lastActiveMaximized"
            ];
          in
          lib.mkOption {
            type = with lib.types; nullOr (enum enumVals);
            default = null;
            example = "activeTask";
            description = ''
              The source of the active task.

              - activeTask: The active task
              - lastActiveTask: The last active task
              - lastActiveMaximized: The last active maximized task
            '';
            apply = getIndexFromEnum enumVals;
          };
        filterByActivity = mkBoolOption "Whether to filter the tasks by activity.";
        filterByScreen = mkBoolOption "Whether to filter the tasks by screen.";
        filterByVirtualDesktop = mkBoolOption "Whether to filter the tasks by virtual desktop.";
        disableForNotMaximized = mkBoolOption "Whether to disable the tasks that are not maximized.";
        disableButtonsForNotHovered = mkBoolOption "Whether to disable the buttons for not hovered tasks.";
      };
      mouseAreaDrag = {
        enable = mkBoolOption "Whether to enable dragging the widget by the mouse area.";
        onlyMaximized = mkBoolOption "Whether to allow dragging the widget only for maximized windows.";
        threshold = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The threshold for dragging the widget.";
        };
        leftDragAction = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on left click drag.";
        };
        middleDragAction = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on middle click drag.";
        };
      };
      mouseAreaClick = {
        enable = mkBoolOption "Whether to enable clicking the widget by the mouse area.";
        leftButtonClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on left click.";
        };
        leftButtonDoubleClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on left double click.";
        };
        leftButtonLongClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on left long press.";
        };
        middleButtonClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on middle click.";
        };
        middleButtonDoubleClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on middle double click.";
        };
        middleButtonLongClick = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on middle long press.";
        };
      };
      mouseAreaWheel = {
        enable = mkBoolOption "Whether to enable scrolling the widget by the mouse area.";
        firstEventDistance = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The distance of the first event.";
        };
        nextEventDistance = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = "The distance of the next event.";
        };
        wheelUp = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on wheel up.";
        };
        wheelDown = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on wheel down.";
        };
        wheelLeft = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on wheel left.";
        };
        wheelRight = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The action to perform on wheel right.";
        };
      };
      titleReplacements = lib.mkOption {
        type = with lib.types; nullOr (listOf titleReplacementType);
        default = null;
        example = [
          {
            type = "string";
            originalTitle = "Brave Web Browser";
            newTitle = "Brave";
          }
          {
            type = "regexp";
            originalTitle = ''\\bDolphin\\b'';
            newTitle = "File manager";
          }
        ];
        description = "The replacements for the window title.";
        apply =
          replacements:
          lib.optionalAttrs (replacements != null) {
            titleReplacementsPatterns = map (r: r.originalTitle) replacements;
            titleReplacementsTemplates = map (r: r.newTitle) replacements;
            titleReplacementsTypes = map (r: r.type) replacements;
          };
      };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          Appearance = {
            windowTitleUndefined = "Plasma";
          };
        };
        description = ''
          Extra configuration for the widget

          See available options at https://github.com/antroids/application-title-bar/blob/main/package/contents/config/main.xml
        '';
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        layout,
        windowControlButtons,
        windowTitle,
        overrideForMaximized,
        behavior,
        mouseAreaDrag,
        mouseAreaClick,
        mouseAreaWheel,
        titleReplacements,
        settings,
        ...
      }:
      {
        name = "com.github.antroids.application-title-bar";
        config = lib.recursiveUpdate {
          Appearance = lib.filterAttrs (_: v: v != null) (
            {
              # Widget layout
              widgetMargins = layout.widgetMargins;
              widgetSpacing = layout.spacingBetweenElements;
              widgetHorizontalAlignment = layout.horizontalAlignment;
              widgetVerticalAlignment = layout.verticalAlignment;
              widgetElementsDisabledMode = layout.showDisabledElements;
              widgetFillWidth = layout.fillFreeSpace;
              widgetElements = layout.elements;

              # Window control buttons
              widgetButtonsIconsTheme = windowControlButtons.iconSource;
              widgetButtonsAuroraeTheme = windowControlButtons.auroraeTheme;
              widgetButtonsMargins = windowControlButtons.buttonsMargin;
              widgetButtonsAspectRatio = windowControlButtons.buttonsAspectRatio;
              widgetButtonsAnimation = windowControlButtons.buttonsAnimationSpeed;

              # Window title
              windowTitleMinimumWidth = windowTitle.minimumWidth;
              windowTitleMaximumWidth = windowTitle.maximumWidth;
              windowTitleHideEmpty = windowTitle.hideEmptyTitle;
              windowTitleUndefined = windowTitle.undefinedWindowTitle;
              windowTitleSource = windowTitle.source;
              windowTitleHorizontalAlignment = windowTitle.horizontalAlignment;
              windowTitleVerticalAlignment = windowTitle.verticalAlignment;

              # Override for maximized windows
              overrideElementsMaximized = overrideForMaximized.enable;
              widgetElementsMaximized = overrideForMaximized.elements;
              windowTitleSourceMaximized = overrideForMaximized.source;
            }
            // windowTitle.font
            // windowTitle.margins
          );
          Behavior = lib.filterAttrs (_: v: v != null) {
            # Behavior
            widgetActiveTaskSource = behavior.activeTaskSource;
            widgetActiveTaskFilterByActivity = behavior.filterByActivity;
            widgetActiveTaskFilterByScreen = behavior.filterByScreen;
            widgetActiveTaskFilterByVirtualDesktop = behavior.filterByVirtualDesktop;
            widgetActiveTaskFilterNotMaximized = behavior.disableForNotMaximized;
            disableButtonsForNotHoveredWidget = behavior.disableButtonsForNotHovered;

            # Mouse area drag
            windowTitleDragEnabled = mouseAreaDrag.enable;
            windowTitleDragOnlyMaximized = mouseAreaDrag.onlyMaximized;
            windowTitleDragThreshold = mouseAreaDrag.threshold;
            widgetMouseAreaLeftDragAction = mouseAreaDrag.leftDragAction;
            widgetMouseAreaMiddleDragAction = mouseAreaDrag.middleDragAction;

            # Mouse area click
            widgetMouseAreaClickEnabled = mouseAreaClick.enable;
            widgetMouseAreaLeftClickAction = mouseAreaClick.leftButtonClick;
            widgetMouseAreaLeftDoubleClickAction = mouseAreaClick.leftButtonDoubleClick;
            widgetMouseAreaLeftLongPressAction = mouseAreaClick.leftButtonLongClick;
            widgetMouseAreaMiddleClickAction = mouseAreaClick.middleButtonClick;
            widgetMouseAreaMiddleDoubleClickAction = mouseAreaClick.middleButtonDoubleClick;
            widgetMouseAreaMiddleLongPressAction = mouseAreaClick.middleButtonLongClick;

            # Mouse area wheel
            widgetMouseAreaWheelEnabled = mouseAreaWheel.enable;
            widgetMouseAreaWheelFirstEventDistance = mouseAreaWheel.firstEventDistance;
            widgetMouseAreaWheelNextEventDistance = mouseAreaWheel.nextEventDistance;
            widgetMouseAreaWheelUpAction = mouseAreaWheel.wheelUp;
            widgetMouseAreaWheelDownAction = mouseAreaWheel.wheelDown;
            widgetMouseAreaWheelLeftAction = mouseAreaWheel.wheelLeft;
            widgetMouseAreaWheelRightAction = mouseAreaWheel.wheelRight;
          };
          TitleReplacements = titleReplacements;
        } settings;
      };
  };
}
