# General workspace behavior settings:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.plasma;

  wallpaperSlideShowType = with lib.types; submodule {
    options = {
      path = lib.mkOption {
        type = either path (listOf path);
        description = "The path(s) where the wallpapers are located.";
      };
      interval = lib.mkOption {
        type = int;
        default = 300;
        description = "The length between wallpaper switches.";
      };
    };
  };

  wallpaperPictureOfTheDayType = with lib.types; submodule {
    options = {
      provider = lib.mkOption {
        type = nullOr (enum [ "apod" "bing" "flickr" "natgeo" "noaa" "wcpotd" "epod" "simonstalenhag" ]);
        description = "The provider for the Picture of the Day plugin.";
      };
      updateOverMeteredConnection = lib.mkOption {
        type = bool;
        default = false;
        description = "Whether to update the wallpaper on a metered connection.";
      };
    };
  };

  cursorType = with lib.types; submodule {
    options = {
      theme = lib.mkOption {
        type = nullOr str;
        default = null;
        example = "Breeze_Snow";
        description = "The Plasma cursortheme. Run plasma-apply-cursortheme --list-themes for valid options.";
      };
      size = lib.mkOption {
        type = nullOr ints.positive;
        default = null;
        example = 24;
        description = "The size of the cursor. See the settings GUI for allowed sizes for each cursortheme.";
      };
    };
  };

  anyThemeSet = (cfg.workspace.theme != null ||
    cfg.workspace.colorScheme != null ||
    (cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null) ||
    cfg.workspace.lookAndFeel != null ||
    cfg.workspace.iconTheme != null);
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "programs" "plasma" "workspace" "cursorTheme" ] [ "programs" "plasma" "workspace" "cursor" "theme" ])
  ];

  options.programs.plasma.workspace = {
    clickItemTo = lib.mkOption {
      type = with lib.types; nullOr (enum [ "open" "select" ]);
      default = null;
      description = ''
        Clicking files or folders should open or select them.
      '';
    };

    tooltipDelay = lib.mkOption {
      type = with lib.types; nullOr ints.positive;
      default = null;
      example = 5;
      description = ''
        The delay in milliseconds before an element's tooltip is shown when hovered over.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "breeze-dark";
      description = ''
        The Plasma theme. Run plasma-apply-desktoptheme --list-themes for valid options.
      '';
    };

    colorScheme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "BreezeDark";
      description = ''
        The Plasma colorscheme. Run plasma-apply-colorscheme --list-schemes for valid options.
      '';
    };

    cursor = lib.mkOption {
      type = lib.types.nullOr cursorType;
      default = null;
      example = { theme = "Breeze_Snow"; size = 24; };
      description = ''
        Allows to configure the cursor in plasma. Both the theme and size are configurable.
      '';
    };

    lookAndFeel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "org.kde.breezedark.desktop";
      description = ''
        The Plasma look and feel theme. Run plasma-apply-lookandfeel --list for valid options.
      '';
    };

    iconTheme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Papirus";
      description = ''
        The Plasma icon theme.
      '';
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png";
      description = ''
        The Plasma wallpaper. Can be either be the path to an image file or a kpackage.
      '';
    };

    wallpaperSlideShow = lib.mkOption {
      type = lib.types.nullOr wallpaperSlideShowType;
      default = null;
      example = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/";
      description = ''
        Allows you to set wallpaper slideshow. Needs a directory of your wallpapers and an interval length.
      '';
    };

    wallpaperPictureOfTheDay = lib.mkOption {
      type = lib.types.nullOr wallpaperPictureOfTheDayType;
      default = null;
      example = { provider = "apod"; };
      description = ''
        Allows you to set wallpaper using the picture of the day plugin. Needs the provider.
      '';
    };
  };

  config = (lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          let
            wallpapers = with cfg.workspace; [ wallpaperSlideShow wallpaper wallpaperPictureOfTheDay ];
          in
          lib.count (x: x != null) wallpapers <= 1;
        message = "Can set only one of wallpaper, wallpaperSlideShow and wallpaperPictureOfTheDay.";
      }
    ];

    programs.plasma.configFile = (lib.mkMerge [
      {
        kdeglobals = (lib.mkIf (cfg.workspace.clickItemTo != null) {
          KDE.SingleClick = (cfg.workspace.clickItemTo == "open");
        });
        plasmarc = (lib.mkIf (cfg.workspace.tooltipDelay != null) {
          PlasmaToolTips.Delay = cfg.workspace.tooltipDelay;
        });
        kcminputrc = (lib.mkIf (cfg.workspace.cursor != null && cfg.workspace.cursor.size != null) {
          Mouse.cursorSize = cfg.workspace.cursor.size;
        });
      }
      # We add persistence to some keys in order to not reset the themes on
      # each generation when we use overrideConfig.
      (lib.mkIf (cfg.overrideConfig && anyThemeSet) (
        let
          colorSchemeIgnore =
            if (cfg.workspace.colorScheme != null) then
              (import ../lib/colorscheme.nix {
                inherit lib;
              }) else { };
        in
        (lib.mkMerge
          [
            {
              kcminputrc.Mouse.cursorTheme.persistent = lib.mkDefault (cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null);
              kdeglobals.General.ColorScheme.persistent = lib.mkDefault (cfg.workspace.colorScheme != null);
              kdeglobals.Icons.Theme.persistent = lib.mkDefault (cfg.workspace.iconTheme != null);
              kdeglobals.KDE.LookAndFeelPackage.persistent = lib.mkDefault (cfg.workspace.lookAndFeel != null);
              plasmarc.Theme.name.persistent = lib.mkDefault (cfg.workspace.theme != null);
            }
            colorSchemeIgnore
          ])
      ))
    ]);

    # We create a script which applies the different theme settings using
    # kde tools. We then run this using an autostart script, where this is
    # run only on the first login (unless overrideConfig is enabled),
    # granted all the commands succeed (until we change the settings again).
    programs.plasma.startup.startupScript."apply_themes" = (lib.mkIf anyThemeSet {
      text = ''
        ${if cfg.workspace.lookAndFeel != null then "plasma-apply-lookandfeel -a ${cfg.workspace.lookAndFeel}" else ""}
        ${if cfg.workspace.theme != null then "plasma-apply-desktoptheme ${cfg.workspace.theme}" else ""}
        ${if (cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null) then
          "plasma-apply-cursortheme ${cfg.workspace.cursor.theme}" +
            (if cfg.workspace.cursor.size != null then " --size ${builtins.toString cfg.workspace.cursor.size}" else "")
          else ""}
        ${if cfg.workspace.colorScheme != null then "plasma-apply-colorscheme ${cfg.workspace.colorScheme}" else ""}
        ${if cfg.workspace.iconTheme != null then "${pkgs.kdePackages.plasma-workspace}/libexec/plasma-changeicons ${cfg.workspace.iconTheme}" else ""}
      '';
      priority = 1;
    });

    # The wallpaper configuration can be found in panels.nix due to wallpaper
    # configuration and panel configuration being stored in the same file, and
    # thus should be using the same desktop-script.
  });
}
