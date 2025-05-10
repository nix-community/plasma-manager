{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.plasma;

  krohnkiteGaps = lib.types.submodule {
    options =
      let
        mkGapOption =
          name:
          lib.mkOption {
            type = with lib.types; nullOr (ints.between 0 999);
            default = null;
            example = 8;
            description = "${name} gap for Krohnkite.";
          };
      in
      {
        top = mkGapOption "Top screen";
        left = mkGapOption "Left screen";
        right = mkGapOption "Right screen";
        bottom = mkGapOption "Bottom screen";
        between = mkGapOption "Gap between tiles";
      };
  };

  krohnkiteSupportedLayouts = [
    {
      value = "btree";
      label = "BTreeLayout";
    }
    {
      value = "monocle";
      label = "MonocleLayout";
    }
    {
      value = "column";
      label = "ColumnsLayout";
    }
    {
      value = "floating";
      label = "FloatingLayout";
    }
    {
      value = "quarter";
      label = "QuarterLayout";
    }
    {
      value = "spiral";
      label = "SpiralLayout";
    }
    {
      value = "threeColumn";
      label = "ThreeColumnLayout";
    }
    {
      value = "tile";
      label = "TileLayout";
    }
    {
      value = "stacked";
      label = "StackedLayout";
    }
    {
      value = "spread";
      label = "SpreadLayout";
    }
    {
      value = "stair";
      label = "StairLayout";
    }
  ];

  krohnkiteLayouts = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = with lib.types; enum (lib.lists.forEach krohnkiteSupportedLayouts (x: x.value));
        description = "The name of the layout.";
      };

      options = lib.mkOption {
        type = with lib.types; nullOr (attrsOf (with lib.types; anything));
        default = null;
        example = {
          maximize = true;
        };
        description = ''
          Layout-specific options. Supported options depend on the layout:
          - `column`: `{ balanced = true; }`
          - `monocle`: `{ maximize = true; minimizeRest = true; }`
          - `stair`: `{ reverse = true; }`
        '';
      };
    };
  };

  mkNullableOption =
    type: description: example:
    lib.mkOption {
      type = with lib.types; nullOr type;
      default = null;
      example = example;
      description = description;
    };

  convertListToString = list: if list == null then null else builtins.concatStringsSep "," list;

  mkFilterOption =
    description: example:
    lib.mkOption {
      type = with lib.types; nullOr (listOf str);
      default = null;
      example = example;
      description = description;
      apply = convertListToString;
    };

  checkIfString = v: if lib.isString v then v else v.name;

  isLayoutEnabled =
    name: lib.any (l: (checkIfString l) == name) cfg.kwin.scripts.krohnkite.settings.layouts.enabled;

  generateOptionsConfig =
    layoutObj:
    if layoutObj.name == "monocle" then
      {
        monocleMaximize = lib.attrByPath [
          "options"
          "maximize"
        ] false layoutObj;
        monocleMinimizeRest = lib.attrByPath [
          "options"
          "minimizeRest"
        ] false layoutObj;
      }
    else if layoutObj.name == "column" then
      {
        columnsBalanced = lib.attrByPath [
          "options"
          "balanced"
        ] false layoutObj;
      }
    else if layoutObj.name == "stair" then
      {
        stairReverse = lib.attrByPath [
          "options"
          "reverse"
        ] false layoutObj;
      }
    else
      { };

  serializeLayouts =
    layouts:
    let
      toLayoutEntry =
        layout:
        let
          layoutEnabled = isLayoutEnabled layout.value;
          layoutObj = lib.findFirst (l: (checkIfString l) == layout.value) { } layouts;
        in
        {
          "enable${layout.label}" = layoutEnabled;
        }
        // (if layoutEnabled && !lib.isString layoutObj then generateOptionsConfig layoutObj else { });
    in
    if layouts != null then
      lib.foldl' lib.recursiveUpdate { } (lib.map toLayoutEntry krohnkiteSupportedLayouts)
    else
      { };
in
{
  options.programs.plasma.kwin.scripts.krohnkite = with lib.types; {
    enable = mkNullableOption bool "Whether to enable Krohnkite." true;

    settings = {
      gaps =
        mkNullableOption krohnkiteGaps
          "Gaps configuration for Krohnkite, e.g., top, bottom, left, right, and between."
          {
            top = 8;
            bottom = 8;
            left = 8;
            right = 8;
            between = 8;
          };

      tileWidthLimit = {
        enable = mkNullableOption bool "Whether to limit tile width for Krohnkite." true;

        ratio = lib.mkOption {
          type = with lib.types; nullOr (numbers.between 0 99);
          default = null;
          example = 1.6;
          description = "Tile width limiting ratio for Krohnkite. Must be a float between 0 and 99.";
        };
      };

      layouts = {
        enabled = lib.mkOption {
          type =
            with lib.types;
            nullOr (
              listOf (either (enum (lib.lists.forEach krohnkiteSupportedLayouts (x: x.value))) krohnkiteLayouts)
            );
          default = null;
          example = [
            "floating"
            {
              name = "monocle";
              options = {
                maximize = true;
              };
            }
          ];
          description = ''
            List of layout configurations for Krohnkite. This can be:
            - An array of strings representing valid layout names, like `["floating" "monocle"]`. Valid values include:
              ${lib.concatStringsSep ", " (lib.lists.forEach krohnkiteSupportedLayouts (x: x.value))}.
            - An array of objects with layout-specific options:
              ```
              [
                { name = "monocle"; options = { maximize = true; }; }
                { name = "column"; options = { balanced = true; }; }
              ]
              ```
            Mixed types are also supported.
          '';
        };
      };

      # Tiling options
      maximizeSoleTile = mkNullableOption bool "Whether to maximize the sole window" true;
      keepFloatAbove = mkNullableOption bool "Whether to keep floating windows above tiled windows" true;
      keepTilingOnDrag =
        mkNullableOption bool "Always preserve the tiling status of the window upon dragging"
          true;
      preventMinimize = mkNullableOption bool "Prevent windows from minimizing" true;
      preventProtrusion = mkNullableOption bool "Prevent window from protruding from its screen" true;
      noTileBorders = mkNullableOption bool "Remove borders of tiled windows" true;
      floatUtility = mkNullableOption bool "Float utility windows" true;

      # Filter rules
      ignoreRoles = mkFilterOption "Ignore windows by role" [ "quake" ];
      ignoreTitles = mkFilterOption "Ignore windows by title" [ "firefox" ];
      ignoreClasses = mkFilterOption "Ignore windows by class" [
        "krunner"
        "yakuake"
        "spectacle"
        "kded5"
        "xwaylandvideobridge"
        "plasmashell"
        "ksplashqml"
        "org.kde.plasmashell"
        "org.kde.polkit-kde-authentication-agent-1"
        "org.kde.kruler"
      ];
      ignoreActivities = mkFilterOption "Disable tiling on activities" [ "Activity1" ];
      ignoreScreens = mkFilterOption "Disable tiling on screens" [ "Screen1" ];
      ignoreVirtualDesktops = mkFilterOption "Disable tiling on virtual desktops" [ "Desktop_1" ];
      floatWindowsByClass = mkFilterOption "Float windows by class" [ "dialog" ];
      floatWindowsByTitle = mkFilterOption "Float windows by title" [ "firefox" ];
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.optionals (cfg.kwin.scripts.krohnkite.enable != null) [ kdePackages.krohnkite ];

    programs.plasma.configFile."kwinrc" = lib.mkIf (cfg.kwin.scripts.krohnkite.enable != null) {
      Plugins.krohnkiteEnabled = cfg.kwin.scripts.krohnkite.enable;
      Script-krohnkite =
        let
          settings = cfg.kwin.scripts.krohnkite.settings;
          gaps = settings.gaps;
          tileWidthLimit = settings.tileWidthLimit;
        in
        serializeLayouts (settings.layouts.enabled)
        // {
          screenGapTop = gaps.top;
          screenGapLeft = gaps.left;
          screenGapRight = gaps.right;
          screenGapBottom = gaps.bottom;
          screenGapBetween = gaps.between;

          limitTileWidth = tileWidthLimit.enable;
          limitTileWidthRatio = tileWidthLimit.ratio;

          # Tiling options
          maximizeSoleTile = settings.maximizeSoleTile;
          keepFloatAbove = settings.keepFloatAbove;
          keepTilingOnDrag = settings.keepTilingOnDrag;
          preventMinimize = settings.preventMinimize;
          preventProtrusion = settings.preventProtrusion;
          noTileBorders = settings.noTileBorders;
          floatUtility = settings.floatUtility;

          # Filter rules
          ignoreRole = settings.ignoreRoles;
          ignoreTitle = settings.ignoreTitles;
          ignoreClass = settings.ignoreClasses;
          ignoreActivity = settings.ignoreActivities;
          ignoreScreen = settings.ignoreScreens;
          ignoreVDesktop = settings.ignoreVirtualDesktops;
          floatingClass = settings.floatWindowsByClass;
          floatingTitle = settings.floatWindowsByTitle;
        };
    };
  };
}
