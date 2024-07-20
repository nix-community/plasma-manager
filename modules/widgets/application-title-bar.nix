{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description: lib.mkOption {
    type = with lib.types; nullOr bool;
    default = null;
    inherit description;
  };

  convertHorizontalAlignment = horizontalAlignment:
    let
      mappings = {
        left = 1;
        right = 2;
        center = 4;
        justify = 8;
      };
    in
      mappings.${horizontalAlignment} or (throw "Invalid enum value: ${horizontalAlignment}");

  convertVerticalAlignment = verticalAlignment:
    let
      mappings = {
        top = 1;
        center = 128;
        bottom = 64;
        baseline = 256;
      };
    in
      mappings.${verticalAlignment} or (throw "Invalid enum value: ${verticalAlignment}");

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (application-title-bar widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  fontType = types.submodule {
    options = {
      bold = mkBoolOption "Enable bold text.";
      fit =
        let enumVals = [ "fixedSize" "horizontalFit" "verticalFit" "fit" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "fixedSize";
          description = "The mode of the size of the font.";
          apply = getIndexFromEnum enumVals;
        };
      size = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "The size of the font.";
      };
    };
  };

  marginType = types.submodule {
    options = {
      left = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "The left margin.";
      };
      right = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "The right margin.";
      };
      top = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "The top margin.";
      };
      bottom = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "The bottom margin.";
      };
    };
  };

  titleReplacementType = types.submodule {
    options = {
      type = 
        let enumVals = [ "string" "regexp" ];
        in mkOption {
          type = types.enum enumVals;
          default = null;
          example = "string";
          description = "The type of the replacement.";
          apply = getIndexFromEnum enumVals;
        };
      originalTitle = mkOption {
        type = types.str;
        example = "Brave Web Browser";
        description = "The original text to replace.";
      };
      newTitle = mkOption {
        type = types.str;
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
      layout = {
        widgetMargins = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The margins around the widget.";
        };
        spacingBetweenElements = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The spacing between elements.";
        };
        horizontalAlignment = mkOption {
          type = types.enum [ "left" "right" "center" "justify" ];
          default = "left";
          description = "The horizontal alignment of the widget.";
          apply = convertHorizontalAlignment;
        };
        verticalAlignment = mkOption {
          type = types.enum [ "top" "center" "bottom" "baseline" ];
          default = "center";
          description = "The vertical alignment of the widget.";
          apply = convertVerticalAlignment;
        };
        showDisabledElements =
          let enumVals = [ "deactivated" "hideKeepSpace" "hide" ];
          in mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "deactivated";
            description = "How to show the elements when the widget is disabled.";
            apply = getIndexFromEnum enumVals;
          };
        fillFreeSpace = mkBoolOption "Whether the widget should fill the free space on the panel.";
        elements = mkOption {
          type = types.nullOr (types.listOf (types.enum [
            "windowCloseButton"
            "windowMinimizeButton"
            "windowMaximizeButton"
            "windowKeepAboveButton"
            "windowKeepBelowButton"
            "windowShadeButton"
            "windowTitle"
            "windowIcon"
            "spacer"
          ]));
          default = null;
          example = [ "windowTitle" ];
          description = ''
            The elements to show in the widget.
          '';
        };
      };
      windowControlButtons = {
        iconSource =
          let enumVals = [ "plasma" "breeze" "aurorae" "oxygen" ];
          in mkOption {
            type = with types; nullOr (enum enumVals);
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
        auroraeTheme = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The Aurorae theme to use for the control buttons.";
        };
        buttonsMargin = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The margin around the buttons.";
        };
        buttonsAspectRatio = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The ratio of button width in percent to 100% of its height. If you need wider buttons, the value should be >100, otherwise less.";
        };
        buttonsAnimationSpeed = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The speed of the buttons animation in milliseconds.";
        };
      };
      windowTitle = {
        minimumWidth = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The minimum width of the window title.";
        };
        maximumWidth = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The maximum width of the window title.";
        };
        font = mkOption {
          type = types.nullOr fontType;
          default = null;
          example = {
            bold = false;
            fit = "FixedSize";
            size = 11;
          };
          description = "The font settings of the window title.";
          apply = font: lib.optionalAttrs (font != null) {
            windowTitleFontBold = font.bold;
            windowTitleFontSize = font.size;
            windowTitleFontSizeMode = font.fit;
          };
        };
        hideEmptyTitle = mkBoolOption "Whether to hide the window title when it's empty.";
        undefinedWindowTitle = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The text to show when the window title is undefined.";
        };
        source =
          let enumVals = [ "appName" "decoration" "genericAppName" "alwaysUndefined" ];
          in mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "appName";
            description = ''
              The source of the window title.

              - appName: The name of the application
              - decoration: The title of the window decoration
              - genericAppName: The generic name of the application
              - alwaysUndefined: Always show the undefined title
            '';
            apply = getIndexFromEnum enumVals;
          };
        margins = mkOption {
          type = types.nullOr marginType;
          default = null;
          example = {
            left = 10;
            right = 10;
            top = 0;
            bottom = 0;
          };
          description = "The margins around the window title.";
          apply = margins: lib.optionalAttrs (margins != null) {
            windowTitleMarginsLeft = margins.left;
            windowTitleMarginsRight = margins.right;
            windowTitleMarginsTop = margins.top;
            windowTitleMarginsBottom = margins.bottom;
          };
        };
      };
      overrideForMaximized = {
        enable = mkBoolOption "Whether to override the settings for maximized windows.";
        elements = mkOption {
          type = types.nullOr (types.listOf (types.enum [
            "windowCloseButton"
            "windowMinimizeButton"
            "windowMaximizeButton"
            "windowKeepAboveButton"
            "windowKeepBelowButton"
            "windowShadeButton"
            "windowTitle"
            "windowIcon"
            "spacer"
          ]));
          default = null;
          example = [ "windowTitle" ];
          description = ''
            The elements to show in the widget for maximized windows.
          '';
        };
        source =
          let
            enumVals = [ "appName" "decoration" "genericAppName" "alwaysUndefined" ];
          in
          mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "appName";
            description = ''
              The source of the window title for maximized windows.

              - appName: The name of the application
              - decoration: The title of the window decoration
              - genericAppName: The generic name of the application
              - alwaysUndefined: Always show the undefined title
            '';
            apply = getIndexFromEnum enumVals;
          };
      };
      behavior = {
        activeTaskSource =
          let enumVals = [ "activeTask" "lastActiveTask" "lastActiveMaximized" ];
          in mkOption {
            type = with types; nullOr (enum enumVals);
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
        threshold = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The threshold for dragging the widget.";
        };
        leftDragAction = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on left click drag.";
        };
        middleDragAction = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on middle click drag.";
        };
      };
      mouseAreaClick = {
        enable = mkBoolOption "Whether to enable clicking the widget by the mouse area.";
        leftButtonClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on left click.";
        };
        leftButtonDoubleClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on left double click.";
        };
        leftButtonLongClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on left long press.";
        };
        middleButtonClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on middle click.";
        };
        middleButtonDoubleClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on middle double click.";
        };
        middleButtonLongClick = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on middle long press.";
        };
      };
      mouseAreaWheel = {
        enable = mkBoolOption "Whether to enable scrolling the widget by the mouse area.";
        firstEventDistance = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The distance of the first event.";
        };
        nextEventDistance = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The distance of the next event.";
        };
        wheelUp = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on wheel up.";
        };
        wheelDown = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on wheel down.";
        };
        wheelLeft = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on wheel left.";
        };
        wheelRight = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The action to perform on wheel right.";
        };
      };
      titleReplacements = mkOption {
        type = with types; nullOr (listOf titleReplacementType);
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
        apply = replacements: lib.optionalAttrs (replacements != null) {
          titleReplacementsPatterns = map (r: r.originalTitle) replacements;
          titleReplacementsTemplates = map (r: r.newTitle) replacements;
          titleReplacementsTypes = map (r: r.type) replacements;
        };
      };
      extraConfig = mkOption {
        type = with types; nullOr (attrsOf (attrsOf (either (oneOf [ bool float int str ]) (listOf (oneOf [ bool float int str ])))));
        default = null;
        example = {
          General = {
            launchers = [ "applications:org.kde.dolphin.desktop" "applications:org.kde.konsole.desktop" ];
          };
        };
        description = ''
          Extra configuration for the widget

          See available options at https://github.com/antroids/application-title-bar/blob/main/package/contents/config/main.xml
        '';
        apply = extraConfig: if extraConfig == null then {} else extraConfig;
      };
    };
    convert =
      { layout
      , windowControlButtons
      , windowTitle
      , overrideForMaximized
      , behavior
      , mouseAreaDrag
      , mouseAreaClick
      , mouseAreaWheel
      , titleReplacements
      , extraConfig
      }: {
        name = "com.github.antroids.application-title-bar";
        config = {
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

              # Override for maximized windows
              overrideElementsMaximized = overrideForMaximized.enable;
              widgetElementsMaximized = overrideForMaximized.elements;
              windowTitleSourceMaximized = overrideForMaximized.source;
            }
            // windowTitle.font
            // windowTitle.margins
          );
          Behavior = lib.filterAttrs (_: v: v != null) (
            {
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
            }
          );
          TitleReplacements = titleReplacements;
        } // extraConfig;
      };
  };
}
