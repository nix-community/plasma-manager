{ config, lib, ... }:

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
  getShortNames = wantedButtons:
    lists.forEach
      (
        lists.flatten (
          lists.forEach wantedButtons (currentButton:
            lists.remove null (
              lists.imap0
                (index: value:
                  if value == currentButton then "${toString index}" else null
                )
                validTitlebarButtons.longNames
            )
          )
        )
      )
      getShortNameFromIndex;

  # Gets the index and returns the short name in that position
  getShortNameFromIndex = position: builtins.elemAt validTitlebarButtons.shortNames (strings.toInt position);

  virtualDesktopNameAttrs = names:
    builtins.listToAttrs
      (imap1 (i: v: (nameValuePair "Name_${builtins.toString i}" { value = v; })) names);
in
{
  options.programs.plasma.kwin = {
    titlebarButtons.right = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [ "help" "minimize" "maximize" "close" ];
      description = ''
        Title bar buttons to be placed on the right.
      '';
    };
    titlebarButtons.left = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [ "on-all-desktops" "keep-above-windows" ];
      description = ''
        Title bar buttons to be placed on the left.
      '';
    };

    effects = {
      shakeCursor.enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = "Enable the shake cursor effect (plasma 6 only).";
      };
    };

    virtualDesktops = {
      animation = mkOption {
        type = with types; nullOr (enum [ "slide" "fade" ]);
        default = null;
        example = "fade";
        description = "The animation when switching virtual desktops.";
      };
      rows = mkOption {
        type = with types; nullOr ints.positive;
        default = null;
        example = 2;
        description = "The amount of rows for the virtual desktops.";
      };
      names = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        example = [ "Desktop 1" "Desktop 2" "Desktop 3" "Desktop 4" ];
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
  };

  config.assertions = [
    {
      assertion =
        cfg.kwin.virtualDesktops.number == null ||
        cfg.kwin.virtualDesktops.names == null ||
        cfg.kwin.virtualDesktops.number == (builtins.length cfg.kwin.virtualDesktops.names);
      message = "programs.plasma.virtualDesktops.number doesn't match the length of programs.plasma.virtualDesktops.names.";
    }
    {
      assertion =
        cfg.kwin.virtualDesktops.rows == null ||
        (cfg.kwin.virtualDesktops.names == null && cfg.kwin.virtualDesktops.number == null) ||
        (cfg.kwin.virtualDesktops.number != null && cfg.kwin.virtualDesktops.number >= cfg.kwin.virtualDesktops.rows) ||
        (cfg.kwin.virtualDesktops.names != null && (builtins.length cfg.kwin.virtualDesktops.names) >= cfg.kwin.virtualDesktops.rows);
      message = "KWin cannot have more rows virtual desktops.";
    }
  ];

  config.programs.plasma.configFile."kwinrc" = mkIf (cfg.enable)
    (mkMerge [
      # Titlebar buttons
      (
        mkIf (cfg.kwin.titlebarButtons.left != null) {
          "org.kde.kdecoration2".ButtonsOnLeft.value = strings.concatStrings (getShortNames cfg.kwin.titlebarButtons.left);
        }
      )
      (
        mkIf (cfg.kwin.titlebarButtons.right != null) {
          "org.kde.kdecoration2".ButtonsOnRight.value = strings.concatStrings (getShortNames cfg.kwin.titlebarButtons.right);
        }
      )

      # Effects
      (
        mkIf (cfg.kwin.effects.shakeCursor.enable != null) {
          Plugins.shakecursorEnabled.value = cfg.kwin.effects.shakeCursor.enable;
        }
      )

      # Virtual Desktops
      (mkIf (cfg.kwin.virtualDesktops.animation != null) {
        Plugins.slideEnabled.value = cfg.kwin.virtualDesktops.animation == "slide";
        Plugins.fadedesktopEnabled.value = cfg.kwin.virtualDesktops.animation == "fade";
      })
      (mkIf (cfg.kwin.virtualDesktops.number != null) {
        Desktops.Number.value = cfg.kwin.virtualDesktops.number;
      })
      (mkIf (cfg.kwin.virtualDesktops.rows != null) {
        Desktops.Rows.value = cfg.kwin.virtualDesktops.rows;
      })
      (mkIf (cfg.kwin.virtualDesktops.names != null) {
        Desktops = mkMerge [
          {
            Number.value = builtins.length cfg.kwin.virtualDesktops.names;
          }
          (virtualDesktopNameAttrs cfg.kwin.virtualDesktops.names)
        ];
      })
    ]);
}
