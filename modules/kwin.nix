{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.plasma;
  validTitlebarButtons = {
    longNames = [
      "more-window-actions"
      "application-menu"
      "on-all-desktops"
      "minimize"
      "maximize"
      "close"
      "help"
      "shade"
      "keep-below-windows"
      "keep-above-windows"
    ];
    shortNames = [
      "M"
      "N"
      "S"
      "I"
      "A"
      "X"
      "H"
      "L"
      "B"
      "F"
    ];
  };

  # Gets a list with long names and turns it into short names
  getShortNames =
    wantedButtons:
    lists.forEach (lists.flatten (
      lists.forEach wantedButtons (
        currentButton:
        lists.remove null (
          lists.imap0 (
            index: value: if value == currentButton then "${toString index}" else null
          ) validTitlebarButtons.longNames
        )
      )
    )) getShortNameFromIndex;

  # Gets the index and returns the short name in that position
  getShortNameFromIndex =
    position: builtins.elemAt validTitlebarButtons.shortNames (strings.toInt position);

  virtualDesktopNameAttrs =
    names: builtins.listToAttrs (imap1 (i: v: (nameValuePair "Name_${builtins.toString i}" v)) names);

  capitalizeWord =
    word:
    let
      firstLetter = builtins.substring 0 1 word;
      rest = builtins.substring 1 (builtins.stringLength word - 1) word;
    in
    "${toUpper firstLetter}${rest}";

  removeColon = string: builtins.replaceStrings [ ":" ] [ "" ] string;

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (
        x: x == value
      ) (throw "getIndexFromEnum (kwin): Value ${value} isn't present in the enum. This is a bug") enum;

  convertPoloniumFilter = list: if list == null then null else builtins.concatStringsSep ", " list;

  tilingLayoutType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "The id of the layout.";
        example = "cf5c25c2-4217-4193-add6-b5971cb543f2";
      };
      tiles = mkOption {
        type = with types; attrsOf anything;
        example = {
          layoutDirection = "horizontal";
          tiles = [
            { width = 0.5; }
            {
              layoutDirection = "vertical";
              tiles = [
                { height = 0.5; }
                { height = 0.5; }
              ];
              width = 0.5;
            }
          ];
        };
        apply = builtins.toJSON;
      };
    };
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "kwin"
        "virtualDesktops"
        "animation"
      ]
      [
        "programs"
        "plasma"
        "kwin"
        "effects"
        "desktopSwitching"
        "animation"
      ]
    )
  ];

  options.programs.plasma.kwin = {
    titlebarButtons.right = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [
        "help"
        "minimize"
        "maximize"
        "close"
      ];
      description = ''
        Title bar buttons to be placed on the right.
      '';
    };
    titlebarButtons.left = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [
        "on-all-desktops"
        "keep-above-windows"
      ];
      description = ''
        Title bar buttons to be placed on the left.
      '';
    };

    effects = {
      shakeCursor.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Enable the shake cursor effect.";
      };
      translucency.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Make windows translucent under different conditions.";
      };
      minimization = {
        animation = mkOption {
          type =
            with types;
            nullOr (enum [
              "squash"
              "magiclamp"
              "off"
            ]);
          default = null;
          example = "magiclamp";
          description = "The effect when windows are minimized.";
        };
        duration = mkOption {
          type = with types; nullOr ints.positive;
          default = null;
          example = 50;
          description = ''
            The duration of the minimization effect in milliseconds. Only
            available when the minimization effect is magic lamp.
          '';
        };
      };
      wobblyWindows.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Deform windows while they are moving.";
      };
      fps.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Display KWin's fps in the corner of the screen;";
      };
      cube.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Arrange desktops in a virtual cube.";
      };
      desktopSwitching.animation = mkOption {
        type =
          with types;
          nullOr (enum [
            "fade"
            "slide"
            "off"
          ]);
        default = null;
        example = "fade";
        description = "The animation used when switching virtual desktop.";
      };
      windowOpenClose = {
        animation = mkOption {
          type =
            with types;
            nullOr (enum [
              "fade"
              "glide"
              "scale"
              "off"
            ]);
          default = null;
          example = "glide";
          description = "The animation used when opening/closing windows.";
        };
      };
      fallApart.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Closed windows fall into pieces.";
      };
      blur = {
        enable = mkOption {
          type = with types; nullOr bool;
          default = null;
          description = "Blurs the background behind semi-transparent windows.";
        };
      };
      snapHelper.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Helps locate the center of the screen when moving a window.";
      };
      dimInactive.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Darken inactive windows.";
      };
      dimAdminMode.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Darken the entire when when requesting root privileges.";
      };
      slideBack.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Slide back windows when another window is raised.";
      };
    };

    virtualDesktops = {
      rows = mkOption {
        type = with types; nullOr ints.positive;
        default = null;
        example = 2;
        description = "The amount of rows for the virtual desktops.";
      };
      names = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        example = [
          "Desktop 1"
          "Desktop 2"
          "Desktop 3"
          "Desktop 4"
        ];
        description = ''
          The names of your virtual desktops. When set, the number of virtual
          desktops is automatically detected and doesn't need to be specified.
        '';
      };
      number = mkOption {
        type = with types; nullOr ints.positive;
        default = null;
        example = 8;
        description = ''
          The amount of virtual desktops. If the names attribute is set as
          well the number of desktops must be the same as the length of the
          names list.
        '';
      };
    };

    borderlessMaximizedWindows = mkOption {
      type = with types; nullOr bool;
      default = null;
      example = true;
      description = "Maximized windows will not have a border.";
    };

    nightLight = {
      enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = "Enable the night light effect.";
      };
      mode = mkOption {
        type =
          with types;
          nullOr (enum [
            "constant"
            "location"
            "times"
          ]);
        default = null;
        example = "times";
        description = "The mode of the night light effect.";
        apply = mode: if mode == null then null else capitalizeWord mode;
      };
      location = {
        latitude = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "39.160305343511446";
          description = "The latitude of your location.";
        };
        longitude = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "-35.86466165413535";
          description = "The longitude of your location.";
        };
      };
      temperature = {
        day = mkOption {
          type = with types; nullOr ints.positive;
          default = null;
          example = 4500;
          description = "The temperature of the screen during the day.";
        };
        night = mkOption {
          type = with types; nullOr ints.positive;
          default = null;
          example = 4500;
          description = "The temperature of the screen during the night.";
        };
      };
      time = {
        morning = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "06:30";
          description = "The exact time when the morning light starts.";
          apply = time: if time == null then null else removeColon time;
        };
        evening = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "19:30";
          description = "The exact time when the evening light starts.";
          apply = time: if time == null then null else removeColon time;
        };
      };
      transitionTime = mkOption {
        type = with types; nullOr ints.positive;
        default = null;
        example = 30;
        description = "The time in minutes it takes to transition from day to night.";
      };
    };

    edgeBarrier = mkOption {
      type = with types; nullOr (ints.between 0 1000);
      default = null;
      example = 50;
      description = ''
        Additional distance the cursor needs to travel to cross screen edges. To
        disable edge-barriers, set this to 0.
      '';
    };

    cornerBarrier = mkOption {
      type = with types; nullOr bool;
      default = null;
      example = false;
      description = "When enabled, prevents the cursor from crossing at screen-corners.";
    };

    tiling = {
      padding = mkOption {
        type = with types; nullOr ints.positive;
        default = null;
        example = 10;
        description = "The padding between windows in tiling.";
      };
      layout = mkOption {
        type = with types; nullOr tilingLayoutType;
        default = null;
        example = {
          id = "cf5c25c2-4217-4193-add6-b5971cb543f2";
          tiles = {
            layoutDirection = "horizontal";
            tiles = [
              { width = 0.5; }
              {
                layoutDirection = "vertical";
                tiles = [
                  { height = 0.5; }
                  { height = 0.5; }
                ];
                width = 0.5;
              }
            ];
          };
        };
      };
    };

    scripts = {
      polonium = {
        enable = mkOption {
          type = with types; nullOr bool;
          default = null;
          example = true;
          description = "Whether to enable Polonium";
        };
        settings = {
          borderVisibility =
            let
              enumVals = [
                "noBorderAll"
                "noBorderTiled"
                "borderSelected"
                "borderAll"
              ];
            in
            mkOption {
              type = with types; nullOr (enum enumVals);
              default = null;
              example = "noBorderAll";
              description = "The border visibility setting for Polonium";
              apply = getIndexFromEnum enumVals;
            };
          callbackDelay = mkOption {
            type = with types; nullOr (ints.between 1 200);
            default = null;
            example = 100;
            description = "The callback delay setting for Polonium";
          };
          enableDebug = mkOption {
            type = with types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to enable debug for Polonium";
          };
          filter = {
            processes = mkOption {
              type = with types; nullOr (listOf str);
              default = null;
              example = [
                "firefox"
                "chromium"
              ];
              description = "The processes to filter for Polonium";
              apply = convertPoloniumFilter;
            };
            windowTitles = mkOption {
              type = with types; nullOr (listOf str);
              default = null;
              example = [
                "Discord"
                "Telegram"
              ];
              description = "The window titles to filter for Polonium";
              apply = convertPoloniumFilter;
            };
          };
          layout = {
            engine =
              let
                enumVals = [
                  "binaryTree"
                  "half"
                  "threeColumn"
                  "monocle"
                  "kwin"
                ];
              in
              mkOption {
                type = with types; nullOr (enum enumVals);
                default = null;
                example = "binaryTree";
                description = "The layout engine setting for Polonium";
                apply = getIndexFromEnum enumVals;
              };
            insertionPoint =
              let
                enumVals = [
                  "left"
                  "right"
                  "activeWindow"
                ];
              in
              mkOption {
                type = with types; nullOr (enum enumVals);
                default = null;
                example = "top";
                description = "The insertion point setting for Polonium";
                apply = getIndexFromEnum enumVals;
              };
            rotate = mkOption {
              type = with types; nullOr bool;
              default = null;
              example = true;
              description = "Whether to rotate layout for Polonium";
            };
          };
          maximizeSingleWindow = mkOption {
            type = with types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to maximize single window for Polonium";
          };
          resizeAmount = mkOption {
            type = with types; nullOr (ints.between 1 450);
            default = null;
            example = 100;
            description = "The resize amount setting for Polonium";
          };
          saveOnTileEdit = mkOption {
            type = with types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to save on tile edit for Polonium";
          };
          tilePopups = mkOption {
            type = with types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to tile popups for Polonium";
          };
        };
      };
    };
  };

  config = (
    mkIf cfg.enable {
      assertions = [
        {
          assertion =
            cfg.kwin.virtualDesktops.number == null
            || cfg.kwin.virtualDesktops.names == null
            || cfg.kwin.virtualDesktops.number == (builtins.length cfg.kwin.virtualDesktops.names);
          message = "programs.plasma.virtualDesktops.number doesn't match the length of programs.plasma.virtualDesktops.names.";
        }
        {
          assertion =
            cfg.kwin.virtualDesktops.rows == null
            || (cfg.kwin.virtualDesktops.names == null && cfg.kwin.virtualDesktops.number == null)
            || (
              cfg.kwin.virtualDesktops.number != null
              && cfg.kwin.virtualDesktops.number >= cfg.kwin.virtualDesktops.rows
            )
            || (
              cfg.kwin.virtualDesktops.names != null
              && (builtins.length cfg.kwin.virtualDesktops.names) >= cfg.kwin.virtualDesktops.rows
            );
          message = "KWin cannot have more rows virtual desktops.";
        }
        {
          assertion =
            cfg.kwin.effects.minimization.duration == null
            || cfg.kwin.effects.minimization.animation == "magiclamp";
          message = "programs.plasma.kwin.effects.minimization.duration is only supported for the magic lamp effect";
        }
        {
          assertion =
            (cfg.kwin.nightLight.enable == null || cfg.kwin.nightLight.enable == false)
            || cfg.kwin.nightLight.mode != null;
          message = "programs.plasma.kwin.nightLight.mode must be set when programs.plasma.kwin.nightLight.enable is true.";
        }
        {
          assertion =
            cfg.kwin.nightLight.mode != "Times"
            || (cfg.kwin.nightLight.time.morning != null && cfg.kwin.nightLight.time.evening != null);
          message = "programs.plasma.kwin.nightLight.time.morning and programs.plasma.kwin.nightLight.time.evening must be set when programs.plasma.kwin.nightLight.mode is set to times.";
        }
        {
          assertion =
            cfg.kwin.nightLight.mode != "Location"
            || (
              cfg.kwin.nightLight.location.latitude != null && cfg.kwin.nightLight.location.longitude != null
            );
          message = "programs.plasma.kwin.nightLight.location.latitude and programs.plasma.kwin.nightLight.location.longitude must be set when programs.plasma.kwin.nightLight.mode is set to location.";
        }
        {
          assertion =
            cfg.kwin.nightLight.time.morning == null
            || builtins.stringLength cfg.kwin.nightLight.time.morning == 4;
          message = "programs.plasma.kwin.nightLight.time.morning must have the exact length of 4. If it doesn't have, it means that it doesn't have this time format: HH:MM";
        }
        {
          assertion =
            cfg.kwin.nightLight.time.evening == null
            || builtins.stringLength cfg.kwin.nightLight.time.evening == 4;
          message = "programs.plasma.kwin.nightLight.time.evening must have the exact length of 4. If it doesn't have, it means that it doesn't have this time format: HH:MM";
        }
      ];

      home.packages = with pkgs; [ ] ++ optionals (cfg.kwin.scripts.polonium.enable == true) [ polonium ];

      programs.plasma.configFile."kwinrc" = (
        mkMerge [
          # Titlebar buttons
          (mkIf (cfg.kwin.titlebarButtons.left != null) {
            "org.kde.kdecoration2".ButtonsOnLeft = strings.concatStrings (
              getShortNames cfg.kwin.titlebarButtons.left
            );
          })
          (mkIf (cfg.kwin.titlebarButtons.right != null) {
            "org.kde.kdecoration2".ButtonsOnRight = strings.concatStrings (
              getShortNames cfg.kwin.titlebarButtons.right
            );
          })

          # Effects
          (mkIf (cfg.kwin.effects.shakeCursor.enable != null) {
            Plugins.shakecursorEnabled = cfg.kwin.effects.shakeCursor.enable;
          })
          (mkIf (cfg.kwin.effects.minimization.animation != null) {
            Plugins = {
              magiclampEnabled = cfg.kwin.effects.minimization.animation == "magiclamp";
              squashEnabled = cfg.kwin.effects.minimization.animation == "squash";
            };
          })
          (mkIf (cfg.kwin.effects.minimization.duration != null) {
            Effect-magiclamp.AnimationDuration = cfg.kwin.effects.minimization.duration;
          })
          (mkIf (cfg.kwin.effects.wobblyWindows.enable != null) {
            Plugins.wobblywindowsEnabled = cfg.kwin.effects.wobblyWindows.enable;
          })
          (mkIf (cfg.kwin.effects.translucency.enable != null) {
            Plugins.translucencyEnabled = cfg.kwin.effects.translucency.enable;
          })
          (mkIf (cfg.kwin.effects.windowOpenClose.animation != null) {
            Plugins = {
              glideEnabled = cfg.kwin.effects.windowOpenClose.animation == "glide";
              fadeEnabled = cfg.kwin.effects.windowOpenClose.animation == "fade";
              scaleEnabled = cfg.kwin.effects.windowOpenClose.animation == "scale";
            };
          })
          (mkIf (cfg.kwin.effects.fps.enable != null) {
            Plugins.showfpsEnabled = cfg.kwin.effects.fps.enable;
          })
          (mkIf (cfg.kwin.effects.cube.enable != null) {
            Plugins.cubeEnabled = cfg.kwin.effects.cube.enable;
          })
          (mkIf (cfg.kwin.effects.desktopSwitching.animation != null) {
            Plugins.slideEnabled = cfg.kwin.effects.desktopSwitching.animation == "slide";
            Plugins.fadedesktopEnabled = cfg.kwin.effects.desktopSwitching.animation == "fade";
          })
          (mkIf (cfg.kwin.effects.fallApart.enable != null) {
            Plugins.fallapartEnabled = cfg.kwin.effects.fallApart.enable;
          })
          (mkIf (cfg.kwin.effects.snapHelper.enable != null) {
            Plugins.snaphelperEnabled = cfg.kwin.effects.snapHelper.enable;
          })
          (mkIf (cfg.kwin.effects.blur.enable != null) {
            Plugins.blurEnabled = cfg.kwin.effects.blur.enable;
          })
          (mkIf (cfg.kwin.effects.dimInactive.enable != null) {
            Plugins.diminactiveEnabled = cfg.kwin.effects.dimInactive.enable;
          })
          (mkIf (cfg.kwin.effects.dimAdminMode.enable != null) {
            Plugins.dimscreenEnabled = cfg.kwin.effects.dimAdminMode.enable;
          })
          (mkIf (cfg.kwin.effects.slideBack.enable != null) {
            Plugins.slidebackEnabled = cfg.kwin.effects.slideBack.enable;
          })

          # Virtual Desktops
          (mkIf (cfg.kwin.virtualDesktops.number != null) {
            Desktops.Number = cfg.kwin.virtualDesktops.number;
          })
          (mkIf (cfg.kwin.virtualDesktops.rows != null) { Desktops.Rows = cfg.kwin.virtualDesktops.rows; })
          (mkIf (cfg.kwin.virtualDesktops.names != null) {
            Desktops = mkMerge [
              { Number = builtins.length cfg.kwin.virtualDesktops.names; }
              (virtualDesktopNameAttrs cfg.kwin.virtualDesktops.names)
            ];
          })

          # Borderless maximized windows
          (mkIf (cfg.kwin.borderlessMaximizedWindows != null) {
            Windows = {
              BorderlessMaximizedWindows = cfg.kwin.borderlessMaximizedWindows;
            };
          })

          # Night Light
          (mkIf (cfg.kwin.nightLight.enable != null) {
            NightColor = {
              Active = cfg.kwin.nightLight.enable;
              DayTemperature = cfg.kwin.nightLight.temperature.day;
              EveningBeginFixed = cfg.kwin.nightLight.time.evening;
              LatitudeFixed = cfg.kwin.nightLight.location.latitude;
              LongitudeFixed = cfg.kwin.nightLight.location.longitude;
              Mode = cfg.kwin.nightLight.mode;
              MorningBeginFixed = cfg.kwin.nightLight.time.morning;
              NightTemperature = cfg.kwin.nightLight.temperature.night;
              TransitionTime = cfg.kwin.nightLight.transitionTime;
            };
          })

          (mkIf (cfg.kwin.cornerBarrier != null) { EdgeBarrier.CornerBarrier = cfg.kwin.cornerBarrier; })
          (mkIf (cfg.kwin.edgeBarrier != null) { EdgeBarrier.EdgeBarrier = cfg.kwin.edgeBarrier; })

          (mkIf (cfg.kwin.scripts.polonium.enable != null) {
            Plugins.poloniumEnabled = cfg.kwin.scripts.polonium.enable;
            Script-polonium = {
              Borders = cfg.kwin.scripts.polonium.settings.borderVisibility;
              Debug = cfg.kwin.scripts.polonium.settings.enableDebug;
              EngineType = cfg.kwin.scripts.polonium.settings.layout.engine;
              FilterCaption = cfg.kwin.scripts.polonium.settings.filter.windowTitles;
              FilterProcess = cfg.kwin.scripts.polonium.settings.filter.processes;
              InsertionPoint = cfg.kwin.scripts.polonium.settings.layout.insertionPoint;
              MaximizeSingle = cfg.kwin.scripts.polonium.settings.maximizeSingleWindow;
              ResizeAmount = cfg.kwin.scripts.polonium.settings.resizeAmount;
              RotateLayout = cfg.kwin.scripts.polonium.settings.layout.rotate;
              SaveOnTileEdit = cfg.kwin.scripts.polonium.settings.saveOnTileEdit;
              TilePopups = cfg.kwin.scripts.polonium.settings.tilePopups;
              TimerDelay = cfg.kwin.scripts.polonium.settings.callbackDelay;
            };
          })

          (mkIf (cfg.kwin.tiling.padding != null) {
            Tiling = {
              padding = cfg.kwin.tiling.padding;
            };
          })

          (mkIf (cfg.kwin.tiling.layout != null) {
            "Tiling/${cfg.kwin.tiling.layout.id}" = {
              tiles = {
                escapeValue = false;
                value = cfg.kwin.tiling.layout.tiles;
              };
            };
          })
        ]
      );
    }
  );
}
