{ lib, ... }:
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

  convertSpacing =
    spacing:
    let
      mappings = {
        small = 0;
        medium = 1;
        large = 3;
      };
    in
    if spacing == null then
      null
    else if builtins.isString spacing then
      mappings.${spacing} or (throw "Invalid spacing: ${spacing}")
    else
      spacing;

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (icon-tasks widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  positionToReverse =
    position:
    let
      mappings = {
        left = true;
        right = false;
      };
    in
    if position == null then null else mappings.${position} or (throw "Invalid position: ${position}");
in
{
  iconTasks = {
    description = "Icons Only Task Manager shows tasks only by their icon and not by icon and title of the window opened.";

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
      launchers = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [
          "applications:org.kde.dolphin.desktop"
          "applications:org.kde.konsole.desktop"
        ];
        description = "The list of launcher tasks on the widget. Usually .desktop file or executable URLs. Special URLs such as preferred://browser that expand to default applications are supported.";
      };
      iconsOnly = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = "Whether to show icons only.";
      };
      appearance = {
        showTooltips = mkBoolOption "Whether to show tooltips when hovering task buttons.";
        highlightWindows = mkBoolOption "Whether to request the window manager highlight windows when hovering corresponding task tooltips.";
        indicateAudioStreams = mkBoolOption "Whether to indicate applications that are playing audio including an option to mute them.";
        fill = mkBoolOption "Whether task manager should occupy all available space.";
        rows = {
          multirowView = mkOption {
            type = types.enum [
              "never"
              "lowSpace"
              "always"
            ];
            default = "never";
            example = "lowSpace";
            description = "When to use multi-row view.";
            apply =
              multirowView:
              if multirowView == "never" then false else (if multirowView == "always" then true else null);
          };
          maximum = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            example = 5;
            description = "The maximum number of rows (in a horizontal-orientation containment, i.e. panel) or columns (in a vertical-orientation containment) to layout task buttons in.";
          };
        };
        iconSpacing = mkOption {
          type = types.nullOr (
            types.oneOf [
              (types.enum [
                "small"
                "medium"
                "large"
              ])
              types.ints.positive
            ]
          );
          default = null;
          example = "small";
          description = "The spacing between icons.";
          apply = convertSpacing;
        };
      };
      behavior = {
        grouping = {
          method =
            let
              enumVals = [
                "none"
                "byProgramName"
              ];
            in
            mkOption {
              type = with types; nullOr (enum enumVals);
              default = null;
              example = "none";
              description = "How tasks are grouped";
              apply = getIndexFromEnum enumVals;
            };
          clickAction =
            let
              enumVals = [
                "cycle"
                "showTooltips"
                "showPresentWindowsEffect"
                "showTextualList"
              ];
            in
            mkOption {
              type = with types; nullOr (enum enumVals);
              default = null;
              example = "cycle";
              description = "What happens when clicking on a grouped task";
              apply = getIndexFromEnum enumVals;
            };
        };
        sortingMethod =
          let
            enumVals = [
              "none"
              "manually"
              "alphabetically"
              "byDesktop"
              "byActivity"
            ];
          in
          mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "manually";
            description = "How to sort tasks";
            apply = getIndexFromEnum enumVals;
          };
        minimizeActiveTaskOnClick = mkBoolOption "Whether to minimize the currently-active task when clicked. If false, clicking on the currently-active task will do nothing.";
        middleClickAction =
          let
            enumVals = [
              "none"
              "close"
              "newInstance"
              "toggleMinimized"
              "toggleGrouping"
              "bringToCurrentDesktop"
            ];
          in
          mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "bringToCurrentDesktop";
            description = "What to do on middle-mouse click on a task button.";
            apply = getIndexFromEnum enumVals;
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
          type = types.nullOr (
            types.enum [
              "left"
              "right"
            ]
          );
          default = null;
          example = "right";
          description = "Whether new tasks should appear in the left or right.";
          apply = positionToReverse;
        };
      };
      settings = mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            launchers = [
              "applications:org.kde.dolphin.desktop"
              "applications:org.kde.konsole.desktop"
            ];
          };
        };
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        appearance,
        behavior,
        launchers,
        settings,
        iconsOnly,
        ...
      }:
      {
        name = if iconsOnly
          then "org.kde.plasma.icontasks"
          else "org.kde.plasma.taskmanager";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) {
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
          };
        } settings;
      };
  };
}
