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
    {
      programs.plasma.configFile.plasmarc = (lib.mkIf (cfg.workspace.tooltipDelay != null) {
        PlasmaToolTips.Delay = cfg.workspace.tooltipDelay;
      });
    }
    {
      # We create a script which applies the different theme settings using
      # kde tools. We then run this using an autostart script, where this is
      # run only on the first login (unless overrideConfig is enabled),
      # granted all the commands succeed (until we change the settings again).
      programs.plasma.startup.startupScript."apply_themes" = (lib.mkIf
        (cfg.workspace.theme != null ||
          cfg.workspace.colorScheme != null ||
          cfg.workspace.cursorTheme != null ||
          cfg.workspace.lookAndFeel != null ||
          cfg.workspace.iconTheme != null)
        {
          text = ''
            ${if cfg.workspace.lookAndFeel != null then "plasma-apply-lookandfeel -a ${cfg.workspace.lookAndFeel}" else ""}
            ${if cfg.workspace.theme != null then "plasma-apply-desktoptheme ${cfg.workspace.theme}" else ""}
            ${if cfg.workspace.cursorTheme != null then "plasma-apply-cursortheme ${cfg.workspace.cursorTheme}" else ""}
            ${if cfg.workspace.colorScheme != null then "plasma-apply-colorscheme ${cfg.workspace.colorScheme}" else ""}
            ${if cfg.workspace.iconTheme != null then "${pkgs.kdePackages.plasma-workspace}/libexec/plasma-changeicons ${cfg.workspace.iconTheme}" else ""}
          '';
          priority = 1;
        });
      # We add persistence to some keys in order to not reset the themes on
      # each generation when we use overrideConfig.
      programs.plasma.configFile = (lib.mkIf (cfg.overrideConfig) (
        let
          colorSchemeIgnore = if (cfg.workspace.colorScheme != null) then (import ../lib/colorscheme.nix { inherit lib; }) else { };
        in
        (lib.mkMerge
          [
            {
              kcminputrc.Mouse.cursorTheme.persistent = lib.mkDefault (cfg.workspace.cursorTheme != null);
              kdeglobals.General.ColorScheme.persistent = lib.mkDefault (cfg.workspace.colorScheme != null);
              kdeglobals.Icons.Theme.persistent = lib.mkDefault (cfg.workspace.iconTheme != null);
              kdeglobals.KDE.LookAndFeelPackage.persistent = lib.mkDefault (cfg.workspace.lookAndFeel != null);
              plasmarc.Theme.name.persistent = lib.mkDefault (cfg.workspace.theme != null);
            }
            colorSchemeIgnore
          ])
      ));
    }
    # Wallpaper and panels are in the same script since the resetting of the
    # panels in the panels-script also has a tendency to reset the wallpaper, so
    # these should run at the same time.
    {
      programs.plasma.startup.desktopScript."panels_and_wallpaper" = (lib.mkIf
        ((cfg.workspace.wallpaper != null) ||
          (cfg.workspace.wallpaperSlideShow != null) ||
          (cfg.workspace.wallpaperPictureOfTheDay != null) ||
          ((builtins.length cfg.panels) > 0))
        (
          let
            anyPanels = ((builtins.length cfg.panels) > 0);
            anyNonDefaultScreens = ((builtins.any (panel: panel.screen != 0)) cfg.panels);
            panelPreCMD = (if anyPanels then ''
              # We delete plasma-org.kde.plasma.desktop-appletsrc to hinder it
              # growing indefinitely. See:
              # https://github.com/pjones/plasma-manager/issues/76
              [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ] && rm ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
            '' else "");
            panelLayoutStr = (if anyPanels then (import ../lib/panel.nix { inherit lib; inherit config; }) else "");
            panelPostCMD = (if anyNonDefaultScreens then ''
              if [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ]; then
                sed -i 's/^lastScreen\\x5b$i\\x5d=/lastScreen[$i]=/' ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
                # We sleep a second in order to prevent some bugs (like the incorrect height being set)
                sleep 1; nohup plasmashell --replace &
              fi
            '' else "");
            # This meaningless comment inserts the URL into the desktop-script
            # which means that when the wallpaper is updated, the sha256 hash
            # changes and the script will be re-run.
            wallpaperDesktopScript = (if (cfg.workspace.wallpaper != null) then ''
              // Wallpaper to set later: ${cfg.workspace.wallpaper}
            '' else "");
            wallpaperPostCMD = (if (cfg.workspace.wallpaper != null) then ''
              plasma-apply-wallpaperimage ${cfg.workspace.wallpaper}
            '' else "");
            wallpaperSlideShow = (if (cfg.workspace.wallpaperSlideShow != null) then ''
              // Wallpaper slideshow
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
            '' else "");
            wallpaperPOTD = (if (cfg.workspace.wallpaperPictureOfTheDay != null) then ''
              // Wallpaper POTD
              let allDesktops = desktops();
              for (const desktop of allDesktops) {
                  desktop.wallpaperPlugin = "org.kde.potd";
                  desktop.currentConfigGroup = ["Wallpaper", "org.kde.potd", "General"];
                  desktop.writeConfig("Provider", "${cfg.workspace.wallpaperPictureOfTheDay.provider}");
                  desktop.writeConfig("UpdateOverMeteredConnection", "${if (cfg.workspace.wallpaperPictureOfTheDay.updateOverMeteredConnection) then "1" else "0"}");
                }
            '' else ""
            );
          in
          {
            preCommands = panelPreCMD;
            text = panelLayoutStr + wallpaperDesktopScript + wallpaperSlideShow + wallpaperPOTD;
            postCommands = panelPostCMD + wallpaperPostCMD;
            priority = 2;
          }
        ));
    }
  ]));
}
