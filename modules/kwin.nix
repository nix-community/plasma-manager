{
  config,
  lib,
  pkgs,
  ...
}:

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
    lib.forEach (lib.flatten (
      lib.forEach wantedButtons (
        currentButton:
        lib.remove null (
          lib.imap0 (
            index: value: if value == currentButton then "${toString index}" else null
          ) validTitlebarButtons.longNames
        )
      )
    )) getShortNameFromIndex;

  # Gets the index and returns the short name in that position
  getShortNameFromIndex =
    position: builtins.elemAt validTitlebarButtons.shortNames (lib.toInt position);

  capitalizeWord =
    word:
    let
      firstLetter = builtins.substring 0 1 word;
      rest = builtins.substring 1 (builtins.stringLength word - 1) word;
    in
    "${lib.toUpper firstLetter}${rest}";

  removeColon = string: builtins.replaceStrings [ ":" ] [ "" ] string;

  hashToUuid =
    hash:
    "${builtins.substring 0 8 hash}-${builtins.substring 8 4 hash}-${builtins.substring 12 4 hash}-${builtins.substring 16 4 hash}-${builtins.substring 20 12 hash}";

  mkTilingLayoutId = seed: hashToUuid (builtins.hashString "sha256" seed);

  resolveTilingLayoutId = seed: mkTilingLayoutId seed;

  desktopSwitchingAnimation =
    if cfg.kwin.effects.desktopSwitching.animation != null then
      cfg.kwin.effects.desktopSwitching.animation
    else if cfg.kwin.virtualDesktops != null then
      cfg.kwin.virtualDesktops.animation
    else
      null;

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (
        x: x == value
      ) (throw "getIndexFromEnum (kwin): Value ${value} isn't present in the enum. This is a bug.") enum;

  convertPoloniumFilter = list: if list == null then null else builtins.concatStringsSep ", " list;

  tilingLayoutType = lib.types.submodule {
    options = {
      tiles = lib.mkOption {
        type = with lib.types; attrsOf anything;
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
      padding = lib.mkOption {
        type = with lib.types; nullOr ints.unsigned;
        default = null;
        example = 0;
        description = "Spacing around tiles in pixels for this layout.";
      };
    };
  };

  virtualDesktopType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the virtual desktop.";
        example = "Work";
      };
      tiling = lib.mkOption {
        type = with lib.types; nullOr tilingLayoutType;
        default = null;
        description = "Optional default tiling layout for this desktop.";
      };
    };
  };

  virtualDesktopsConfigType = lib.types.submodule {
    options = {
      desktops = lib.mkOption {
        type = with lib.types; listOf virtualDesktopType;
        description = "List of virtual desktops to create.";
        example = [
          { name = "Work"; }
          { name = "Play"; }
        ];
      };
      rows = lib.mkOption {
        type = with lib.types; nullOr ints.positive;
        default = null;
        example = 1;
        description = "The number of rows for arranging the virtual desktops grid.";
      };
      outputIds = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [
          "65b5772f-051d-432a-ba6a-dce5cdbc32dc"
          "301b0961-14e3-42bf-9114-a20c47b005f4"
        ];
        description = ''
          KWin display (monitor/screen) output UUIDs to write
          per-virtual-desktop tiling layouts for.
          KWin stores desktop tiling in `Tiling/<desktop-id>/<display-uuid>`.

          If empty, output UUIDs are auto-detected during Home Manager
          activation from `kwinoutputconfig.json` and existing `kwinrc`
          `Tiling` groups.

          The current output UUID is used by KWin 6.6+, while older Plasma
          releases may still read the legacy output ID.
        '';
      };
      animation = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "fade"
            "slide"
            "off"
          ]);
        default = null;
        description = ''
          Deprecated compatibility option for desktop switching animation.
          Prefer `programs.plasma.kwin.effects.desktopSwitching.animation`.
        '';
      };
    };
  };
in
{
  options.programs.plasma.kwin = {
    titlebarButtons.right = lib.mkOption {
      type = with lib.types; nullOr (listOf (enum validTitlebarButtons.longNames));
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
    titlebarButtons.left = lib.mkOption {
      type = with lib.types; nullOr (listOf (enum validTitlebarButtons.longNames));
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
      hideCursor = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable the hide cursor effect.";
        };
        hideOnInactivity = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          example = 0;
          description = "Hide cursor after inactivity in seconds.";
        };
        hideOnTyping = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = true;
          description = "Hide cursor effect while typing.";
        };
      };
      invert.enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable the invert effect toggle.";
      };
      zoom = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = true;
          description = "Enable the zoom effect.";
        };
        zoomFactor = lib.mkOption {
          type = with lib.types; nullOr numbers.positive;
          default = null;
          example = 1.2;
          description = "Set the zoom factor.";
        };
        pixelGridZoom = lib.mkOption {
          type = with lib.types; nullOr numbers.positive;
          default = null;
          example = 15.0;
          description = "Set the zoom level of the pixel grid.";
        };
        mousePointer =
          let enumVals = [
            "scale"
            "keep"
            "hide"
          ];
          in
            lib.mkOption {
              type = with lib.types; nullOr (enum enumVals);
              default = null;
              example = "scale";
              description = "Set the mouse pointer style.";
              apply = getIndexFromEnum enumVals;
            };
        mouseTracking =
          let
            enumVals = [
            "proportional"
            "centered"
            "push"
            "disabled"
          ];
          in
            lib.mkOption {
            type = with lib.types; nullOr (enum enumVals);
            default = null;
            example = "proportional";
            description = "Set the mouse tracking style.";
            apply = getIndexFromEnum enumVals;
            };
        focusTracking.enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable focus tracking.";
        };
        textCursorTracking.enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable text cursor tracking.";
        };
        scrollGestureModKeys = lib.mkOption {
          type = with lib.types; nullOr (oneOf [
            (listOf str)
            str
          ]);
          default = null;
          example = "Meta+Ctrl";
          description = "Set scroll gesture modifier keys.";
        };
      };
      magnifier = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable the magnifier effect.";
        };
        height = lib.mkOption {
          type = with lib.types; nullOr ints.positive;
          default = null;
          example = 200;
          description = "Height of the magnifier section in pixels.";
        };
        width = lib.mkOption {
          type = with lib.types; nullOr ints.positive;
          default = null;
          example = 200;
          description = "Width of the magnifier section in pixels.";
        };
      };
      shakeCursor.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Enable the shake cursor effect.";
      };
      translucency.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Make windows translucent under certain conditions.";
      };
      minimization = {
        animation = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "squash"
              "magiclamp"
              "off"
            ]);
          default = null;
          example = "magiclamp";
          description = "The effect to be displayed when windows are minimized.";
        };
        duration = lib.mkOption {
          type = with lib.types; nullOr ints.positive;
          default = null;
          example = 50;
          description = ''
            The duration of the minimization effect in milliseconds. Only
            available when the minimization effect is `magiclamp`.
          '';
        };
      };
      wobblyWindows.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Deform windows while they are moving.";
      };
      fps.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Display KWin's FPS performance graph in the corner of the screen.";
      };
      cube.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Arrange desktops in a virtual cube.";
      };
      desktopSwitching = {
        animation = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "fade"
              "slide"
              "off"
            ]);
          default = null;
          example = "fade";
          description = "The animation used when switching through virtual desktops.";
        };
        navigationWrapping = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          description = "Whether to wrap around when switching through virtual desktops.";
        };
      };
      windowOpenClose = {
        animation = lib.mkOption {
          type =
            with lib.types;
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
      fallApart.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Whether to make closed windows break into pieces.";
      };
      blur = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          description = "Blurs the background behind semi-transparent windows.";
        };
        strength = lib.mkOption {
          type = with lib.types; nullOr (ints.between 1 15);
          default = null;
          example = 5;
          description = "Controls the intensity of the blur.";
        };
        noiseStrength = lib.mkOption {
          type = with lib.types; nullOr (ints.between 0 14);
          default = null;
          example = 8;
          description = "Adds noise to the blur effect.";
        };
      };
      snapHelper.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Helps locate the center of the screen when moving a window.";
      };
      dimInactive.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Darken inactive windows.";
      };
      dimAdminMode.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Darken the entire screen, except for the PolKit window, when requesting `root` privileges.";
      };
      slideBack.enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        description = "Slide back windows when another window is raised.";
      };
    };

    virtualDesktops = lib.mkOption {
      type = with lib.types; nullOr virtualDesktopsConfigType;
      default = null;
      example = {
        desktops = [
          {
            name = "Work";
            tiling = {
              tiles = {
                layoutDirection = "horizontal";
                tiles = [
                  { width = 0.5; }
                  { width = 0.5; }
                ];
              };
            };
          }
          {
            name = "Play";
          }
        ];
        rows = 1;
      };
      description = ''
        Virtual desktops to create. The `desktops` list defines each desktop
        with an optional tiling layout. The `rows` option arranges them in a grid.
      '';
    };

    borderlessMaximizedWindows = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      description = "Whether to remove the border of maximized windows.";
    };

    nightLight = {
      enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Enable the night light effect.";
      };
      mode = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "automatic"
            "constant"
            "location"
            "times"
          ]);
        default = null;
        example = "times";
        description = ''
          When to enable the night light effect.

          - `automatic` enables it from sunset to sunrise based on your system's location queried from geoclue.
          - `constant` enables it unconditonally.
          - `location` uses coordinates to figure out the sunset/sunrise times for your location.
          - `times` allows you to set the times for enabling and disabling night light.
        '';
        apply = mode: if mode == null then null else capitalizeWord mode;
      };
      location = {
        latitude = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "39.160305343511446";
          description = "The latitude of your location.";
        };
        longitude = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "-35.86466165413535";
          description = "The longitude of your location.";
        };
      };
      temperature = {
        day = lib.mkOption {
          type = with lib.types; nullOr ints.positive;
          default = null;
          example = 4500;
          description = "The temperature of the screen during the day.";
        };
        night = lib.mkOption {
          type = with lib.types; nullOr ints.positive;
          default = null;
          example = 4500;
          description = "The temperature of the screen during the night.";
        };
      };
      time = {
        morning = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "06:30";
          description = "The exact time when the morning light starts.";
          apply = time: if time == null then null else removeColon time;
        };
        evening = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "19:30";
          description = "The exact time when the evening light starts.";
          apply = time: if time == null then null else removeColon time;
        };
      };
      transitionTime = lib.mkOption {
        type = with lib.types; nullOr ints.positive;
        default = null;
        example = 30;
        description = "The time in minutes it takes to transition from day to night.";
      };
    };

    edgeBarrier = lib.mkOption {
      type = with lib.types; nullOr (ints.between 0 1000);
      default = null;
      example = 50;
      description = ''
        Additional distance the cursor needs to travel to cross screen edges. To
        disable edge barriers, set this to `0`.
      '';
    };

    cornerBarrier = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = false;
      description = "When enabled, prevents the cursor from crossing at screen-corners.";
    };

    tiling = {
      layout = lib.mkOption {
        type = with lib.types; nullOr tilingLayoutType;
        default = null;
        example = {
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
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = true;
          description = "Whether to enable Polonium.";
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
            lib.mkOption {
              type = with lib.types; nullOr (enum enumVals);
              default = null;
              example = "noBorderAll";
              description = "The border visibility setting for Polonium.";
              apply = getIndexFromEnum enumVals;
            };
          callbackDelay = lib.mkOption {
            type = with lib.types; nullOr (ints.between 1 200);
            default = null;
            example = 100;
            description = "The callback delay setting for Polonium.";
          };
          enableDebug = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to enable debug mode for Polonium.";
          };
          filter = {
            processes = lib.mkOption {
              type = with lib.types; nullOr (listOf str);
              default = null;
              example = [
                "firefox"
                "chromium"
              ];
              description = "The processes to filter for Polonium.";
              apply = convertPoloniumFilter;
            };
            windowTitles = lib.mkOption {
              type = with lib.types; nullOr (listOf str);
              default = null;
              example = [
                "Discord"
                "Telegram"
              ];
              description = "The window titles to filter for Polonium.";
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
              lib.mkOption {
                type = with lib.types; nullOr (enum enumVals);
                default = null;
                example = "binaryTree";
                description = "The layout engine setting for Polonium.";
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
              lib.mkOption {
                type = with lib.types; nullOr (enum enumVals);
                default = null;
                example = "top";
                description = "The insertion point setting for Polonium.";
                apply = getIndexFromEnum enumVals;
              };
            rotate = lib.mkOption {
              type = with lib.types; nullOr bool;
              default = null;
              example = true;
              description = "Whether to rotate the layout for Polonium.";
            };
          };
          maximizeSingleWindow = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to maximize a single window for Polonium.";
          };
          resizeAmount = lib.mkOption {
            type = with lib.types; nullOr (ints.between 1 450);
            default = null;
            example = 100;
            description = "The resize amount setting for Polonium.";
          };
          saveOnTileEdit = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to save on tile edit for Polonium.";
          };
          tilePopups = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
            example = true;
            description = "Whether to tile popups for Polonium.";
          };
        };
      };
    };
  };

  config = (
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion =
            cfg.kwin.virtualDesktops == null
            || cfg.kwin.virtualDesktops.rows == null
            || (builtins.length cfg.kwin.virtualDesktops.desktops) >= cfg.kwin.virtualDesktops.rows;
          message = "KWin cannot have more rows than virtual desktops.";
        }
        {
          assertion =
            cfg.kwin.virtualDesktops == null
            || cfg.kwin.virtualDesktops.animation == null
            || cfg.kwin.effects.desktopSwitching.animation == null
            || cfg.kwin.virtualDesktops.animation == cfg.kwin.effects.desktopSwitching.animation;
          message = "Use either programs.plasma.kwin.virtualDesktops.animation or programs.plasma.kwin.effects.desktopSwitching.animation, or set both to the same value.";
        }
        {
          assertion =
            (cfg.kwin.effects.zoom.enable == null || cfg.kwin.effects.zoom.enable == false)
            || (cfg.kwin.effects.magnifier.enable == null || cfg.kwin.effects.magnifier.enable == false);
          message = "programs.plasma.kwin.effects.zoom.enable and programs.plasma.kwin.effects.magnifier.enable cannot both be true.";
        }
        {
          assertion =
            cfg.kwin.effects.minimization.duration == null
            || cfg.kwin.effects.minimization.animation == "magiclamp";
          message = "programs.plasma.kwin.effects.minimization.duration is only supported for the magic lamp effect";
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

      home.packages =
        with pkgs;
        [ ] ++ lib.optionals (cfg.kwin.scripts.polonium.enable == true) [ polonium ];

      home.activation.plasmaKwinAutoApplyDesktopTiling =
        let
          desktops = if cfg.kwin.virtualDesktops == null then [ ] else cfg.kwin.virtualDesktops.desktops;
          desktopsWithTiling = lib.filter (d: d.tiling != null) desktops;
          autoDetectOutputIds = cfg.kwin.virtualDesktops != null && desktopsWithTiling != [ ] && cfg.kwin.virtualDesktops.outputIds == [ ];
          desktopApplyCommands = lib.concatStringsSep "\n" (
            lib.imap1 (i: d:
              lib.optionalString (d.tiling != null)
                (let
                  desktopId = "Desktop_${builtins.toString i}";
                  paddingValue = if d.tiling.padding == null then "__NULL__" else builtins.toString d.tiling.padding;
                in
                ''
                  apply_tiling "${desktopId}" "$output_id" ${lib.escapeShellArg d.tiling.tiles} ${lib.escapeShellArg paddingValue}
                '')
            ) desktops
          );
        in
        lib.mkIf autoDetectOutputIds (lib.hm.dag.entryAfter [ "configure-plasma" ] ''
          set -eu

          config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}"
          kwinrc="$config_dir/kwinrc"
          kwinoutputconfig="$config_dir/kwinoutputconfig.json"
          kwriteconfig="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
          grep_bin="${pkgs.gnugrep}/bin/grep"
          sed_bin="${pkgs.gnused}/bin/sed"
          sort_bin="${pkgs.coreutils}/bin/sort"
          mktemp_bin="${pkgs.coreutils}/bin/mktemp"
          rm_bin="${pkgs.coreutils}/bin/rm"

          if [ ! -f "$kwinrc" ] || [ ! -x "$kwriteconfig" ]; then
            exit 0
          fi

          output_ids_tmp="$($mktemp_bin)"
          output_ids_unique_tmp="$($mktemp_bin)"
          trap '"$rm_bin" -f "$output_ids_tmp" "$output_ids_unique_tmp"' EXIT

          apply_tiling() {
            desktop_id="$1"
            output_id="$2"
            tiles_json="$3"
            padding_value="$4"

            "$kwriteconfig" --file "$kwinrc" --group Tiling --group "$desktop_id" --group "$output_id" --key tiles "$tiles_json"
            if [ "$padding_value" != "__NULL__" ]; then
              "$kwriteconfig" --file "$kwinrc" --group Tiling --group "$desktop_id" --group "$output_id" --key padding "$padding_value"
            fi
          }

          if [ -f "$kwinoutputconfig" ]; then
            "$grep_bin" -oE '"uuid"[[:space:]]*:[[:space:]]*"[0-9a-fA-F-]{36}"' "$kwinoutputconfig" | "$sed_bin" -E 's/.*"([0-9a-fA-F-]{36})"/\1/' >> "$output_ids_tmp" || true
          fi

          "$grep_bin" -oE '^\[Tiling\]\[[^]]+\]\[[0-9a-fA-F-]{36}\]$' "$kwinrc" | "$sed_bin" -E 's/^\[Tiling\]\[[^]]+\]\[([0-9a-fA-F-]{36})\]$/\1/' >> "$output_ids_tmp" || true

          "$sort_bin" -u "$output_ids_tmp" > "$output_ids_unique_tmp"

          while IFS= read -r output_id; do
            [ -n "$output_id" ] || continue
            ${desktopApplyCommands}
          done < "$output_ids_unique_tmp"
        '');

      programs.plasma.configFile."kwinrc" = (
        lib.mkMerge [
          # Titlebar buttons
          (lib.mkIf (cfg.kwin.titlebarButtons.left != null) {
            "org.kde.kdecoration2".ButtonsOnLeft = lib.concatStrings (
              getShortNames cfg.kwin.titlebarButtons.left
            );
          })
          (lib.mkIf (cfg.kwin.titlebarButtons.right != null) {
            "org.kde.kdecoration2".ButtonsOnRight = lib.concatStrings (
              getShortNames cfg.kwin.titlebarButtons.right
            );
          })

          # Effects
          (lib.mkIf (cfg.kwin.effects.hideCursor.enable != null) {
            Plugins.hidecursorEnabled = cfg.kwin.effects.hideCursor.enable;
            Effect-hidecursor = {
              InactivityDuration = cfg.kwin.effects.hideCursor.hideOnInactivity;
              HideOnTyping = cfg.kwin.effects.hideCursor.hideOnTyping;
            };
          })
          (lib.mkIf (cfg.kwin.effects.invert.enable != null) {
            Plugins.invertEnabled = cfg.kwin.effects.invert.enable;
          })
          (lib.mkIf (cfg.kwin.effects.zoom.enable != null) {
            Plugins.zoomEnabled = cfg.kwin.effects.zoom.enable;
            Effect-zoom = {
              ZoomFactor = cfg.kwin.effects.zoom.zoomFactor;
              PixelGridZoom = cfg.kwin.effects.zoom.pixelGridZoom;
              MousePointer = cfg.kwin.effects.zoom.mousePointer;
              MouseTracking = cfg.kwin.effects.zoom.mouseTracking;
              EnableFocusTracking = cfg.kwin.effects.zoom.focusTracking.enable;
              EnableTextCaretTracking = cfg.kwin.effects.zoom.textCursorTracking.enable;
              PointerAxisGestureModifiers = cfg.kwin.effects.zoom.scrollGestureModKeys;
            };
          })
          (lib.mkIf (cfg.kwin.effects.magnifier.enable != null) {
            Plugins.magnifierEnabled = cfg.kwin.effects.magnifier.enable;
            Effect-magnifier = {
              Height = cfg.kwin.effects.magnifier.height;
              Width = cfg.kwin.effects.magnifier.width;
            };
          })
          (lib.mkIf (cfg.kwin.effects.shakeCursor.enable != null) {
            Plugins.shakecursorEnabled = cfg.kwin.effects.shakeCursor.enable;
          })
          (lib.mkIf (cfg.kwin.effects.minimization.animation != null) {
            Plugins = {
              magiclampEnabled = cfg.kwin.effects.minimization.animation == "magiclamp";
              squashEnabled = cfg.kwin.effects.minimization.animation == "squash";
            };
          })
          (lib.mkIf (cfg.kwin.effects.minimization.duration != null) {
            Effect-magiclamp.AnimationDuration = cfg.kwin.effects.minimization.duration;
          })
          (lib.mkIf (cfg.kwin.effects.wobblyWindows.enable != null) {
            Plugins.wobblywindowsEnabled = cfg.kwin.effects.wobblyWindows.enable;
          })
          (lib.mkIf (cfg.kwin.effects.translucency.enable != null) {
            Plugins.translucencyEnabled = cfg.kwin.effects.translucency.enable;
          })
          (lib.mkIf (cfg.kwin.effects.windowOpenClose.animation != null) {
            Plugins = {
              glideEnabled = cfg.kwin.effects.windowOpenClose.animation == "glide";
              fadeEnabled = cfg.kwin.effects.windowOpenClose.animation == "fade";
              scaleEnabled = cfg.kwin.effects.windowOpenClose.animation == "scale";
            };
          })
          (lib.mkIf (cfg.kwin.effects.fps.enable != null) {
            Plugins.showfpsEnabled = cfg.kwin.effects.fps.enable;
          })
          (lib.mkIf (cfg.kwin.effects.cube.enable != null) {
            Plugins.cubeEnabled = cfg.kwin.effects.cube.enable;
          })
          (lib.mkIf (desktopSwitchingAnimation != null) {
            Plugins.slideEnabled = desktopSwitchingAnimation == "slide";
            Plugins.fadedesktopEnabled = desktopSwitchingAnimation == "fade";
          })
          (lib.mkIf (cfg.kwin.effects.desktopSwitching.navigationWrapping != null) {
            Windows.RollOverDesktops = cfg.kwin.effects.desktopSwitching.navigationWrapping;
          })
          (lib.mkIf (cfg.kwin.effects.fallApart.enable != null) {
            Plugins.fallapartEnabled = cfg.kwin.effects.fallApart.enable;
          })
          (lib.mkIf (cfg.kwin.effects.snapHelper.enable != null) {
            Plugins.snaphelperEnabled = cfg.kwin.effects.snapHelper.enable;
          })
          (lib.mkIf (cfg.kwin.effects.blur.enable != null) {
            Plugins.blurEnabled = cfg.kwin.effects.blur.enable;
            Effect-blur = {
              BlurStrength = cfg.kwin.effects.blur.strength;
              NoiseStrength = cfg.kwin.effects.blur.noiseStrength;
            };
          })
          (lib.mkIf (cfg.kwin.effects.dimInactive.enable != null) {
            Plugins.diminactiveEnabled = cfg.kwin.effects.dimInactive.enable;
          })
          (lib.mkIf (cfg.kwin.effects.dimAdminMode.enable != null) {
            Plugins.dimscreenEnabled = cfg.kwin.effects.dimAdminMode.enable;
          })
          (lib.mkIf (cfg.kwin.effects.slideBack.enable != null) {
            Plugins.slidebackEnabled = cfg.kwin.effects.slideBack.enable;
          })

          # Virtual Desktops
          (lib.mkIf (cfg.kwin.virtualDesktops != null) (
            let
              desktops = cfg.kwin.virtualDesktops.desktops;
              desktopConfig = lib.mkMerge [
                {
                  Desktops = lib.mkMerge [
                    { Number = builtins.length desktops; }
                    (builtins.listToAttrs (lib.imap1 (i: _: lib.nameValuePair "Id_${builtins.toString i}" "Desktop_${builtins.toString i}") desktops))
                    (builtins.listToAttrs (lib.imap1 (i: d: lib.nameValuePair "Name_${builtins.toString i}" d.name) desktops))
                  ];
                }
                (lib.mkIf (cfg.kwin.virtualDesktops.rows != null) {
                  Desktops.Rows = cfg.kwin.virtualDesktops.rows;
                })
              ];
              tilingConfig =
                builtins.listToAttrs (
                  (lib.concatLists (
                    lib.imap1 (i: d:
                      let
                        kwinDesktopId = "Desktop_${builtins.toString i}";
                      in
                      lib.optionals (d.tiling != null) (
                        lib.forEach cfg.kwin.virtualDesktops.outputIds (
                          outputId:
                          let
                            sectionKey = "Tiling/${kwinDesktopId}/${outputId}";
                          in
                          lib.nameValuePair sectionKey (
                            lib.mkMerge [
                              {
                                tiles = {
                                  escapeValue = false;
                                  value = d.tiling.tiles;
                                };
                              }
                              (lib.mkIf (d.tiling.padding != null) {
                                padding = d.tiling.padding;
                              })
                            ]
                          )
                        )
                      )
                    ) desktops
                  ))
                );
            in
            lib.mkMerge [
              desktopConfig
              (lib.mkIf ((builtins.length (lib.filter (d: d.tiling != null) desktops) > 0) && (cfg.kwin.virtualDesktops.outputIds != [ ])) tilingConfig)
            ]
          ))

          # Borderless maximized windows
          (lib.mkIf (cfg.kwin.borderlessMaximizedWindows != null) {
            Windows = {
              BorderlessMaximizedWindows = cfg.kwin.borderlessMaximizedWindows;
            };
          })

          # Night Light
          (lib.mkIf (cfg.kwin.nightLight.enable != null) {
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

          (lib.mkIf (cfg.kwin.cornerBarrier != null) { EdgeBarrier.CornerBarrier = cfg.kwin.cornerBarrier; })
          (lib.mkIf (cfg.kwin.edgeBarrier != null) { EdgeBarrier.EdgeBarrier = cfg.kwin.edgeBarrier; })

          (lib.mkIf (cfg.kwin.scripts.polonium.enable != null) {
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

          (lib.mkIf (cfg.kwin.tiling.layout != null) {
            "Tiling/${resolveTilingLayoutId "kwin-tiling-global-layout-v1"}" = lib.mkMerge [
              {
                tiles = {
                  escapeValue = false;
                  value = cfg.kwin.tiling.layout.tiles;
                };
              }
              (lib.mkIf (cfg.kwin.tiling.layout.padding != null) {
                padding = cfg.kwin.tiling.layout.padding;
              })
            ];
          })
        ]
      );
    }
  );
}
