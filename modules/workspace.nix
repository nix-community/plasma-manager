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
in
{
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

    cursorTheme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Breeze_Snow";
      description = ''
        The Plasma cursortheme. Run plasma-apply-cursortheme --list-themes for valid options.
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
      example = "${pkgs.libsForQt5.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png";
      description = ''
        The Plasma wallpaper. Can be either be the path to an image file or a kpackage.
      '';
    };

    wallpaperSlideShow = lib.mkOption {
      type = lib.types.nullOr wallpaperSlideShowType;
      default = null;
      example = "${pkgs.libsForQt5.plasma-workspace-wallpapers}/share/wallpapers/";
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

  config = (lib.mkIf cfg.enable (lib.mkMerge [
    {
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
    }
    {
      programs.plasma.configFile.kdeglobals = (lib.mkIf (cfg.workspace.clickItemTo != null) {
        KDE.SingleClick = (cfg.workspace.clickItemTo == "open");
      });
    }
    (lib.mkIf (cfg.workspace.tooltipDelay != null) {
      programs.plasma.configFile.plasmarc = {
        PlasmaToolTips.Delay = cfg.workspace.tooltipDelay;
      };
    })
    (lib.mkIf
      (cfg.workspace.theme != null ||
        cfg.workspace.colorScheme != null ||
        cfg.workspace.cursorTheme != null ||
        cfg.workspace.lookAndFeel != null ||
        cfg.workspace.iconTheme != null)
      {
        # We create a script which applies the different theme settings using
        # kde tools. We then run this using an autostart script, where this is
        # run only on the first login (unless overrideConfig is enabled),
        # granted all the commands succeed (until we change the settings again).
        programs.plasma.startup.startupScript."apply_themes" = {
          text = ''
            ${if cfg.workspace.lookAndFeel != null then "plasma-apply-lookandfeel -a ${cfg.workspace.lookAndFeel}" else ""}
            ${if cfg.workspace.theme != null then "plasma-apply-desktoptheme ${cfg.workspace.theme}" else ""}
            ${if cfg.workspace.cursorTheme != null then "plasma-apply-cursortheme ${cfg.workspace.cursorTheme}" else ""}
            ${if cfg.workspace.colorScheme != null then "plasma-apply-colorscheme ${cfg.workspace.colorScheme}" else ""}
            ${if cfg.workspace.iconTheme != null then "${pkgs.libsForQt5.plasma-workspace}/libexec/plasma-changeicons ${cfg.workspace.iconTheme}" else ""}
          '';
          priority = 1;
        };
      })
    (lib.mkIf (cfg.workspace.wallpaper != null) {
      # We need to set the wallpaper after the panels are created in order for
      # this not to be reset when specifying the screens for panels. See:
      # https://github.com/pjones/plasma-manager/issues/116.
      programs.plasma.startup.startupScript."set_wallpaper" = {
        text = ''
          plasma-apply-wallpaperimage ${cfg.workspace.wallpaper}
        '';
        priority = 3;
      };
    })
    (lib.mkIf (cfg.workspace.wallpaperSlideShow != null) {
      programs.plasma.startup.desktopScript."set_wallpaper_slideshow" = {
        text = ''
          let allDesktops = desktops();
          for (var desktopIndex = 0; desktopIndex < allDesktops.length; desktopIndex++) {
              var desktop = allDesktops[desktopIndex];
              desktop.wallpaperPlugin = "org.kde.slideshow";
              desktop.currentConfigGroup = Array("Wallpaper", "org.kde.slideshow", "General");
              desktop.writeConfig("SlidePaths", ${if (builtins.isPath cfg.workspace.wallpaperSlideShow.path) then
              "\"" + cfg.workspace.wallpaperSlideShow.path + "\"" else
              "[" + (builtins.concatStringsSep "," (map (s: "\"" + s + "\"") cfg.workspace.wallpaperSlideShow.path)) + "]"});
              desktop.writeConfig("SlideInterval", "${builtins.toString cfg.workspace.wallpaperSlideShow.interval}");
          }
        '';
        priority = 3;
      };
    })
    (lib.mkIf (cfg.workspace.wallpaperPictureOfTheDay != null) {
      programs.plasma.startup.desktopScript."set_wallpaper_potd" = {
        text = ''
          let allDesktops = desktops();
          for (const desktop of allDesktops) {
              desktop.wallpaperPlugin = "org.kde.potd";
              desktop.currentConfigGroup = ["Wallpaper", "org.kde.potd", "General"];
              desktop.writeConfig("Provider", "${cfg.workspace.wallpaperPictureOfTheDay.provider}");
              desktop.writeConfig("UpdateOverMeteredConnection", "${if (cfg.workspace.wallpaperPictureOfTheDay.updateOverMeteredConnection) then "1" else "0"}");
            }
        '';
        priority = 3;
      };
    })
  ]));
}
