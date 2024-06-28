{ lib, widgets, ... }:
let
  inherit (lib) mkOption types;
  inherit (widgets.lib) mkBoolOption mkEnumOption;

  convertHorizontalAlignment = horizontalAlignment: let
    mappings = {
      "left" = "1";
      "right" = "2";
      "center" = "4";
      "justify" = "8";
    };
  in
    mappings.${horizontalAlignment} or (throw "Invalid enum value: ${horizontalAlignment}");

  convertVerticalAlignment = verticalAlignment: let
    mappings = {
      "top" = "1";
      "center" = "128";
      "bottom" = "64";
      "baseline" = "256";
    };
  in
    mappings.${verticalAlignment} or (throw "Invalid enum value: ${verticalAlignment}");

  fontType = types.submodule {
    options = {
      bold = mkBoolOption "Enable bold text.";
      fit = mkEnumOption [ "FixedSize" "HorizontalFit" "VerticalFit" "Fit" ] // {
        example = "FixedSize";
        description = "The mode of the size of the font.";
      };
      size = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "The size of the font.";
        apply = builtins.toString;
      };
    };
  };

  marginType = types.submodule {
    options = {
      left = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "The left margin.";
        apply = builtins.toString;
      };
      right = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "The right margin.";
        apply = builtins.toString;
      };
      top = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "The top margin.";
        apply = builtins.toString;
      };
      bottom = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "The bottom margin.";
        apply = builtins.toString;
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
          apply = builtins.toString;
        };
        spacingBetweenElements = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The spacing between elements.";
          apply = builtins.toString;
        };
        horizontalAlignment = mkOption {
          type = types.nullOr (types.enum [ "left" "right" "center" "justify" ]);
          default = null;
          description = "The horizontal alignment of the widget.";
          apply = convertHorizontalAlignment;
        };
        verticalAlignment = mkOption {
          type = types.nullOr (types.enum [ "top" "center" "bottom" "baseline" ]);
          default = null;
          description = "The vertical alignment of the widget.";
          apply = convertVerticalAlignment;
        };
        showDisableElements = mkEnumOption [ "Deactivated" "HideKeepSpace" "Hide" ] // {
          example = "Deactivated";
          description = "How to show the elements when the widget is disabled.";
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
        iconSource = mkEnumOption [ "Plasma" "Breeze" "Aurorae" "Oxygen" ] // {
          example = "Plasma";
          description = ''
            The icon source for the control buttons.

            - Plasma: Global icon theme
            - Breeze: Implicit Breeze icons
            - Aurorae: Window decorations theme
            - Oxygen: Implicit Oxygen icons
          '';
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
          apply = builtins.toString;
        };
        buttonsAspectRatio = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The ratio of button width in percent to 100% of its height. If you need wider buttons, the value should be >100, otherwise less.";
          apply = builtins.toString;
        };
        buttonsAnimationSpeed = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The speed of the buttons animation in milliseconds.";
          apply = builtins.toString;
        };
      };
      windowTitle = {
        minimumWidth = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The minimum width of the window title.";
          apply = builtins.toString;
        };
        maximumWidth = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The maximum width of the window title.";
          apply = builtins.toString;
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
        source = mkEnumOption [ "AppName" "Decoration" "GenericAppName" "AlwaysUndefined" ] // {
          example = "AppName";
          description = ''
            The source of the window title.

            - AppName: The name of the application
            - Decoration: The title of the window decoration
            - GenericAppName: The generic name of the application
            - AlwaysUndefined: Always show the undefined title
          '';
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
        source = mkEnumOption [ "AppName" "Decoration" "GenericAppName" "AlwaysUndefined" ] // {
          example = "AppName";
          description = ''
            The source of the window title for maximized windows.

            - AppName: The name of the application
            - Decoration: The title of the window decoration
            - GenericAppName: The generic name of the application
            - AlwaysUndefined: Always show the undefined title
          '';
        };
      };
      behavior = {
        activeTaskSource = mkEnumOption [ "ActiveTask" "LastActiveTask" "LastActiveMaximized" ] // {
          example = "ActiveTask";
          description = ''
            The source of the active task.

            - ActiveTask: The active task
            - LastActiveTask: The last active task
            - LastActiveMaximized: The last active maximized task
          '';
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
          apply = builtins.toString;
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
          apply = builtins.toString;
        };
        nextEventDistance = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "The distance of the next event.";
          apply = builtins.toString;
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
            widgetElementsDisabledMode = layout.showDisableElements;
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
      };
    };
  };
}