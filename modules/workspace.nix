# General workspace behavior settings:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.plasma;

  inherit (import ../lib/wallpapers.nix { inherit lib; })
    wallpaperPictureOfTheDayType
    wallpaperSlideShowType
    wallpaperFillModeTypes
    ;

  cursorType =
    with lib.types;
    submodule {
      options = {
        theme = lib.mkOption {
          type = nullOr str;
          default = null;
          example = "Breeze_Snow";
          description = "The Plasma cursor theme. Run `plasma-apply-cursortheme --list-themes` for valid options.";
        };
        size = lib.mkOption {
          type = nullOr ints.positive;
          default = null;
          example = 24;
          description = "The size of the cursor. See the System Settings app for allowed sizes for each cursor theme.";
        };
      };
    };

  anyThemeSet = (
    cfg.workspace.theme != null
    || cfg.workspace.colorScheme != null
    || (cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null)
    || cfg.workspace.lookAndFeel != null
    || cfg.workspace.iconTheme != null
  );

  splashScreenEngineDetect = theme: (if (theme == "None") then "none" else "KSplashQML");
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "workspace"
        "cursorTheme"
      ]
      [
        "programs"
        "plasma"
        "workspace"
        "cursor"
        "theme"
      ]
    )
  ];

  options.programs.plasma.workspace = {
    clickItemTo = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "open"
          "select"
        ]);
      default = null;
      description = ''
        Whether clicking files or folders should open or select them.
      '';
    };

    enableMiddleClickPaste = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = false;
      description = ''
        Whether clicking the middle mouse button pastes the clipboard content.";
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
      type = with lib.types; nullOr str;
      default = null;
      example = "breeze-dark";
      description = ''
        The Plasma style. Run `plasma-apply-desktoptheme --list-themes` for valid options.
      '';
    };

    colorScheme = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "BreezeDark";
      description = ''
        The Plasma color scheme. Run `plasma-apply-colorscheme --list-schemes` for valid options.
      '';
    };

    cursor = lib.mkOption {
      type = lib.types.nullOr cursorType;
      default = null;
      example = {
        theme = "Breeze_Snow";
        size = 24;
      };
      description = ''
        Submodule for configuring the cursor appearance. Both the theme and size are configurable.
      '';
    };

    lookAndFeel = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "org.kde.breezedark.desktop";
      description = ''
        The Plasma Global Theme. Run `plasma-apply-lookandfeel --list` for valid options.
      '';
    };

    iconTheme = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Papirus";
      description = ''
        The Plasma icon theme.
      '';
    };

    wallpaper = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = lib.literalExpression ''"''${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png"'';
      description = ''
        The Plasma desktop wallpaper. Can be either the path to an image file or a KPackage.
      '';
    };

    wallpaperSlideShow = lib.mkOption {
      type = lib.types.nullOr wallpaperSlideShowType;
      default = null;
      example = lib.literalExpression ''{ path = "''${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/"; }'';
      description = ''
        Submodule for configuring the wallpaper slideshow. Needs a directory with wallpapers and an interval length.
      '';
    };

    wallpaperPictureOfTheDay = lib.mkOption {
      type = lib.types.nullOr wallpaperPictureOfTheDayType;
      default = null;
      example = {
        provider = "apod";
      };
      description = ''
        Which plugin to fetch the Picture of the Day from.
      '';
    };

    wallpaperPlainColor = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "0,64,174,256";
      description = ''
        Set the wallpaper using a plain color. Color is a comma-seperated R,G,B,A string. The alpha is optional (default is 256).
      '';
    };

    wallpaperFillMode = lib.mkOption {
      type = with lib.types; nullOr (enum (builtins.attrNames wallpaperFillModeTypes));
      default = null;
      example = "stretch";
      description = ''
        Defines how the wallpaper should be displayed on the screen.
        Applies only to `wallpaper`, `wallpaperPictureOfTheDay` or `wallpaperSlideShow`.
      '';
    };

    soundTheme = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "freedesktop";
      description = ''
        The sound theme to use with Plasma.
      '';
    };

    splashScreen = {
      engine = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "none";
        description = ''
          The engine for the splash screen theme. If not specified, Plasma will try
          to set an appropriate engine, but this may fail, in which case this option
          should be specified manually.
        '';
      };
      theme = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "None";
        description = ''
          The splash screen theme shown at login. To view all available values, see the
          `Theme` key in `$HOME/.config/ksplashrc` after imperatively applying the splash screen via
          the System Settings app. Can also be set to `None` to disable the splash screen
          altogether.
        '';
      };
    };

    windowDecorations = {
      library = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "org.kde.kwin.aurorae";
        description = ''
          The library for the window decorations theme. To view all available values,
          see the `library` key in the `org.kde.kdecoration2` section of
          `$HOME/.config/kwinrc` after imperatively applying the window decoration via the
          System Settings app.
        '';
      };
      theme = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "__aurorae__svg__CatppuccinMocha-Modern";
        description = ''
          The window decorations theme. To view all available values, see the `theme` key
          in the `org.kde.kdecoration2` section of `$HOME/.config/kwinrc` after
          imperatively applying the window decoration via the System Settings app.
        '';
      };
    };
  };

  config = (
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion =
            let
              wallpapers = with cfg.workspace; [
                wallpaperSlideShow
                wallpaper
                wallpaperPictureOfTheDay
                wallpaperPlainColor
              ];
            in
            lib.count (x: x != null) wallpapers <= 1;
          message = "Can set only one of wallpaper, wallpaperSlideShow, wallpaperPictureOfTheDay, and wallpaperPlainColor.";
        }
        {
          assertion = (cfg.workspace.splashScreen.engine == null || cfg.workspace.splashScreen.theme != null);
          message = ''
            Cannot set plasma.workspace.splashScreen.engine without a
            corresponding theme.
          '';
        }
        {
          assertion =
            !(lib.xor (cfg.workspace.windowDecorations.theme == null) (
              cfg.workspace.windowDecorations.library == null
            ));
          message = ''
            Must set both plasma.workspace.windowDecorations.library and
            plasma.workspace.windowDecorations.theme or none.
          '';
        }
      ];
      warnings = (
        if
          (
            (cfg.workspace.lookAndFeel != null)
            && (cfg.workspace.splashScreen.theme != null || cfg.workspace.windowDecorations.theme != null)
          )
        then
          [
            ''
              Setting lookAndFeel together with splashScreen or windowDecorations in
              plasma-manager is not recommended since lookAndFeel themes often
              override these settings. Consider setting each part in the lookAndFeel
              theme manually.
            ''
          ]
        else
          [ ]
      );

      programs.plasma.configFile = (
        lib.mkMerge [
          {
            kdeglobals = {
              KDE.SingleClick = (
                lib.mkIf (cfg.workspace.clickItemTo != null) (cfg.workspace.clickItemTo == "open")
              );
              Sounds.Theme = (lib.mkIf (cfg.workspace.soundTheme != null) cfg.workspace.soundTheme);
            };
            plasmarc = (
              lib.mkIf (cfg.workspace.tooltipDelay != null) { PlasmaToolTips.Delay = cfg.workspace.tooltipDelay; }
            );
            kcminputrc = (
              lib.mkIf (cfg.workspace.cursor != null && cfg.workspace.cursor.size != null) {
                Mouse.cursorSize = cfg.workspace.cursor.size;
              }
            );
            ksplashrc.KSplash = (
              lib.mkIf (cfg.workspace.splashScreen.theme != null) {
                Engine = (
                  if (cfg.workspace.splashScreen.engine == null) then
                    (splashScreenEngineDetect cfg.workspace.splashScreen.theme)
                  else
                    cfg.workspace.splashScreen.engine
                );
                Theme = cfg.workspace.splashScreen.theme;
              }
            );
            kwinrc =
              (lib.mkIf (cfg.workspace.windowDecorations.theme != null) {
                "org.kde.kdecoration2".library = cfg.workspace.windowDecorations.library;
                "org.kde.kdecoration2".theme = cfg.workspace.windowDecorations.theme;
              })
              // (lib.optionalAttrs (cfg.workspace.enableMiddleClickPaste != null) {
                Wayland.EnablePrimarySelection = cfg.workspace.enableMiddleClickPaste;
              });
          }
          # We add persistence to some keys in order to not reset the themes on
          # each generation when we use overrideConfig.
          (lib.mkIf (cfg.overrideConfig && anyThemeSet) (
            let
              colorSchemeIgnore =
                if (cfg.workspace.colorScheme != null || cfg.workspace.lookAndFeel != null) then
                  (import ../lib/colorscheme.nix { inherit lib; })
                else
                  { };
            in
            (lib.mkMerge [
              {
                kcminputrc.Mouse.cursorTheme.persistent = lib.mkDefault (
                  cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null
                );
                kdeglobals.General.ColorScheme.persistent = lib.mkDefault (
                  cfg.workspace.colorScheme != null || cfg.workspace.lookAndFeel != null
                );
                kdeglobals.Icons.Theme.persistent = lib.mkDefault (cfg.workspace.iconTheme != null);
                kdeglobals.KDE.LookAndFeelPackage.persistent = lib.mkDefault (cfg.workspace.lookAndFeel != null);
                plasmarc.Theme.name.persistent = lib.mkDefault (cfg.workspace.theme != null);
              }
              colorSchemeIgnore
            ])
          ))
        ]
      );

      # We create a script which applies the different theme settings using
      # kde tools. We then run this using an autostart script, where this is
      # run only on the first login (unless overrideConfig is enabled),
      # granted all the commands succeed (until we change the settings again).
      programs.plasma.startup = {
        startupScript."apply_themes" = (
          lib.mkIf anyThemeSet {
            text = ''
              ${
                if cfg.workspace.lookAndFeel != null then
                  "plasma-apply-lookandfeel -a ${cfg.workspace.lookAndFeel}"
                else
                  ""
              }
              ${if cfg.workspace.theme != null then "plasma-apply-desktoptheme ${cfg.workspace.theme}" else ""}
              ${
                if (cfg.workspace.cursor != null && cfg.workspace.cursor.theme != null) then
                  "plasma-apply-cursortheme ${cfg.workspace.cursor.theme}"
                  + (
                    if cfg.workspace.cursor.size != null then
                      " --size ${builtins.toString cfg.workspace.cursor.size}"
                    else
                      ""
                  )
                else
                  ""
              }
              ${
                if cfg.workspace.colorScheme != null then
                  "plasma-apply-colorscheme ${cfg.workspace.colorScheme}"
                else
                  ""
              }
              ${
                if cfg.workspace.iconTheme != null then
                  "${pkgs.kdePackages.plasma-workspace}/libexec/plasma-changeicons ${cfg.workspace.iconTheme}"
                else
                  ""
              }
            '';
            priority = 1;
          }
        );

        desktopScript."wallpaper_picture" = (
          lib.mkIf (cfg.workspace.wallpaper != null) {
            # We just put this here as we need this script to be a desktop-script in
            # order to link it together with the other desktop-script (namely
            # panels). Adding a comment with the wallpaper makes it so that when the
            # wallpaper changes, the sha256sum also changes for the js file, which
            # gives us the correct behavior with last_run files.
            text = "// Wallpaper to set later: ${cfg.workspace.wallpaper}";
            postCommands = ''
              plasma-apply-wallpaperimage ${cfg.workspace.wallpaper} ${
                lib.optionalString (
                  cfg.workspace.wallpaperFillMode != null
                ) "--fill-mode ${cfg.workspace.wallpaperFillMode}"
              }
            '';
            priority = 3;
          }
        );

        desktopScript."wallpaper_potd" = (
          lib.mkIf (cfg.workspace.wallpaperPictureOfTheDay != null) {
            text = ''
              // Wallpaper POTD
              let allDesktops = desktops();
              for (const desktop of allDesktops) {
                  desktop.wallpaperPlugin = "org.kde.potd";
                  desktop.currentConfigGroup = ["Wallpaper", "org.kde.potd", "General"];
                  desktop.writeConfig("Provider", "${cfg.workspace.wallpaperPictureOfTheDay.provider}");
                  desktop.writeConfig("UpdateOverMeteredConnection", "${
                    if (cfg.workspace.wallpaperPictureOfTheDay.updateOverMeteredConnection) then "1" else "0"
                  }");
                  ${
                    lib.optionalString (cfg.workspace.wallpaperFillMode != null)
                      ''desktop.writeConfig("FillMode", "${
                        toString wallpaperFillModeTypes.${cfg.workspace.wallpaperFillMode}
                      }");''
                  }
              }
            '';
            priority = 3;
          }
        );

        desktopScript."wallpaper_plaincolor" = (
          lib.mkIf (cfg.workspace.wallpaperPlainColor != null) {
            text = ''
              // Wallpaper plain color
              let allDesktops = desktops();
              for (var desktopIndex = 0; desktopIndex < allDesktops.length; desktopIndex++) {
                  var desktop = allDesktops[desktopIndex];
                  desktop.wallpaperPlugin = "org.kde.color";
                  desktop.currentConfigGroup = Array("Wallpaper", "org.kde.color", "General");
                  desktop.writeConfig("Color", "${cfg.workspace.wallpaperPlainColor}");
              }
            '';
            priority = 3;
          }
        );

        desktopScript."wallpaper_slideshow" = (
          lib.mkIf (cfg.workspace.wallpaperSlideShow != null) {
            text = ''
              // Wallpaper slideshow
              let allDesktops = desktops();
              for (var desktopIndex = 0; desktopIndex < allDesktops.length; desktopIndex++) {
                  var desktop = allDesktops[desktopIndex];
                  desktop.wallpaperPlugin = "org.kde.slideshow";
                  desktop.currentConfigGroup = Array("Wallpaper", "org.kde.slideshow", "General");
                  desktop.writeConfig("SlidePaths", ${
                    with cfg.workspace.wallpaperSlideShow;
                    if ((builtins.isPath path) || (builtins.isString path)) then
                      "\"" + (builtins.toString path) + "\""
                    else
                      "[" + (builtins.concatStringsSep "," (map (s: "\"" + s + "\"") path)) + "]"
                  });
                  desktop.writeConfig("SlideInterval", "${builtins.toString cfg.workspace.wallpaperSlideShow.interval}");
                  ${
                    lib.optionalString (cfg.workspace.wallpaperFillMode != null)
                      ''desktop.writeConfig("FillMode", "${
                        toString wallpaperFillModeTypes.${cfg.workspace.wallpaperFillMode}
                      }");''
                  }
              }
            '';
            priority = 3;
          }
        );
      };
    }
  );
}
