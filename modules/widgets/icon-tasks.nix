{ lib, widgets, ... }:
let
  inherit (lib) mkOption types;
  inherit (widgets.lib) mkBoolOption mkEnumOption;

  convertSpacing = spacing: let
    mappings = {
      "Small" = "0";
      "Medium" = "1";
      "Large" = "3";
    };
  in mappings.${spacing} or (throw "Invalid spacing: ${spacing}");

  positionToReverse = position: let
    mappings = { "Left" = "true"; "Right" = "false"; };
  in mappings.${position} or (throw "Invalid position: ${position}");
in
{
  iconTasks = {
    description = "Icons Only Task Manager shows tasks only by their icon and not by icon and title of the window opened.";

    opts = {
      launchers = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [ "applications:org.kde.dolphin.desktop" "applications:org.kde.konsole.desktop" ];
        description = "The list of launcher tasks on the widget. Usually .desktop file or executable URLs. Special URLs such as preferred://browser that expand to default applications are supported.";
      };
      appearance = {
        showTooltips = mkBoolOption "Whether to show tooltips when hovering task buttons.";
        highlightWindows = mkBoolOption "Whether to request the window manager highlight windows when hovering corresponding task tooltips.";
        indicateAudioStreams = mkBoolOption "Whether to indicate applications that are playing audio including an option to mute them.";
        fill = mkBoolOption "Whether task manager should occupy all available space.";
        rows = {
          multirowView = mkOption {
            type = types.enum [ "Never" "LowSpace" "Always" ];
            default = "Never";
            example = "LowSpace";
            description = "When to use multi-row view.";
            apply = multirowView: if multirowView == "Never" then "false" else (if multirowView == "Always" then "true" else null);
          };
          maximum = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            example = 5;
            description = "The maximum number of rows (in a horizontal-orientation containment, i.e. panel) or columns (in a vertical-orientation containment) to layout task buttons in.";
            apply = builtins.toString;
          };
        };
        iconSpacing = mkOption {
          type = types.enum [ "Small" "Medium" "Large" ];
          default = "Medium";
          example = "Small";
          description = "The spacing between icons.";
          apply = convertSpacing;
        };
      };
      behavior = {
        grouping = {
          method = mkEnumOption [ "None" "ByProgramName" ] // {
            example = "None";
            description = "How tasks are grouped";
          };  
          clickAction = mkEnumOption [ "Cycle" "ShowTooltips" "ShowPresentWindowsEffect" "ShowTextualList" ] // {
            example = "Cycle";
            description = "What happens when clicking on a grouped task";
          };
        };
        sortingMethod = mkEnumOption [ "None" "Manually" "Alphabetically" "ByDesktop" "ByActivity" ] // {
          example = "Manually";
          description = "How to sort tasks";
        };
        minimizeActiveTaskOnClick = mkBoolOption "Whether to minimize the currently-active task when clicked. If false, clicking on the currently-active task will do nothing.";
        middleClickAction = mkEnumOption [ "None" "Close" "NewInstance" "ToggleMinimized" "ToggleGrouping" "BringToCurrentDesktop" ] // {
          example = "BringToCurrentDesktop";
          description = "What to do on middle-mouse click on a task button.";
        };
        wheel = {
          switchBetweenTasks = mkBoolOption "Whether using the mouse wheel with the mouse pointer above the widget should switch between tasks.";
          ignoreMinimizedTasks = mkBoolOption "Whether to skip minimized tasks when switching between them using the mouse wheel.";
        };
        showTasks = {
          onlyInCurrentScreen = mkBoolOption "Whether to show only window tasks that are on the same screen as the widget.";
          onlyInCurrentDesktop = mkBoolOption "Whether to only show tasks that are on the current virtual desktop.";
          onlyInCurrentActivity = mkBoolOption "Whether to show only tasks that are on the current activity.";
          onlyMinimized = mkBoolOption "Whether to show only window tasks that are minimized.";
        };
        unhideOnAttentionNeeded = mkBoolOption "Whether to unhide if a window wants attention.";
        newTasksAppearOn = mkOption {
          type = types.enum [ "Left" "Right" ];
          default = "Right";
          example = "Left";
          description = "Whether new tasks should appear in the left or right.";
          apply = positionToReverse;
        };
      };
    };
    convert =
      { appearance
      , behavior
      , launchers }: {
      name = "org.kde.plasma.icontasks";
      config.General = lib.filterAttrs (_: v: v != null) (
          {
            launchers = launchers;

            # Appearance
            showToolTips = appearance.showTooltips;
            highlightWindows = appearance.highlightWindows;
            indicateAudioStreams = appearance.indicateAudioStreams;
            fill = appearance.fill;

            forceStripes = appearance.rows.multirowView;
            maxStripes = appearance.rows.maximum;

            iconSpacing = appearance.iconSpacing;

            # Behavior
            groupingStrategy = behavior.grouping.method;
            groupedTaskVisualization = behavior.grouping.clickAction;
            sortingStrategy = behavior.sortingMethod;
            minimizeActiveTaskOnClick = behavior.minimizeActiveTaskOnClick;
            middleClickAction = behavior.middleClickAction;

            wheelEnabled = behavior.wheel.switchBetweenTasks;
            wheelSkipMinimized = behavior.wheel.ignoreMinimizedTasks;

            showOnlyCurrentScreen = behavior.showTasks.onlyInCurrentScreen;
            showOnlyCurrentDesktop = behavior.showTasks.onlyInCurrentDesktop;
            showOnlyCurrentActivity = behavior.showTasks.onlyInCurrentActivity;
            showOnlyMinimized = behavior.showTasks.onlyMinimized;

            unhideOnAttention = behavior.unhideOnAttentionNeeded;
            reverseMode = behavior.newTasksAppearOn;
          }
        );
    };
  };
}