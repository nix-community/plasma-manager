{ config, lib, ... }:
let
  cfg = config.programs.plasma;
  inherit (import ../lib/wallpapers.nix { inherit lib; })
    wallpaperPictureOfTheDayType
    wallpaperSlideShowType
    ;
in
{
  options.programs.plasma.kscreenlocker = {
    autoLock = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      description = ''
        Whether the screen will be locked after the specified time.
      '';
    };
    lockOnResume = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = false;
      description = ''
        Whether to lock the screen when the system resumes from sleep.
      '';
    };

    timeout = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      example = 5;
      description = ''
        Sets the timeout in minutes after which the screen will be locked.
      '';
    };

    passwordRequired = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      description = ''
        Whether the user password is required to unlock the screen.
      '';
    };

    passwordRequiredDelay = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      example = 5;
      description = ''
        The time it takes in seconds for the password to be required after the screen is locked.
      '';
    };

    lockOnStartup = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = false;
      description = ''
        Whether to lock the screen on startup.

        **Note:** This option is not provided in the System Settings app.
      '';
    };

    appearance = {
      alwaysShowClock = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to always show the clock on the lockscreen, even if the unlock dialog is not shown.
        '';
      };
      showMediaControls = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to show media controls on the lockscreen.
        '';
      };

      wallpaper = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        example = lib.literalExpression ''"''${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png"'';
        description = ''
          The wallpaper for the lockscreen. Can be either the path to an image file or a KPackage.
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
      wallpaperSlideShow = lib.mkOption {
        type = lib.types.nullOr wallpaperSlideShowType;
        default = null;
        example = lib.literalExpression ''{ path = "''${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/"; }'';
        description = ''
          Allows you to set the wallpaper using the slideshow plugin. Needs the path
          to at least one directory with wallpaper images.
        '';
      };
      wallpaperPlainColor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "0,64,174,256";
        description = ''
          Set the wallpaper using a plain color. Color is a comma-seperated R,G,B,A string. The alpha is optional (default is 256).
        '';
      };
    };
  };

  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "wallpaper"
      ]
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "appearance"
        "wallpaper"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "wallpaperPictureOfTheDay"
      ]
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "appearance"
        "wallpaperPictureOfTheDay"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "wallpaperSlideShow"
      ]
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "appearance"
        "wallpaperSlideShow"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "wallpaperPlainColor"
      ]
      [
        "programs"
        "plasma"
        "kscreenlocker"
        "appearance"
        "wallpaperPlainColor"
      ]
    )
  ];

  config = {
    assertions = [
      {
        assertion =
          let
            wallpapers = with cfg.kscreenlocker.appearance; [
              wallpaperSlideShow
              wallpaper
              wallpaperPictureOfTheDay
              wallpaperPlainColor
            ];
          in
          lib.count (x: x != null) wallpapers <= 1;
        message = "Can set only one of wallpaper, wallpaperSlideShow, wallpaperPictureOfTheDay, and wallpaperPlainColor for kscreenlocker.";
      }
    ];
    programs.plasma.configFile.kscreenlockerrc = (
      lib.mkMerge [
        (lib.mkIf (cfg.kscreenlocker.appearance.wallpaper != null) {
          Greeter.WallpaperPlugin = "org.kde.image";
          "Greeter/Wallpaper/org.kde.image/General".Image = (
            builtins.toString cfg.kscreenlocker.appearance.wallpaper
          );
        })
        (lib.mkIf (cfg.kscreenlocker.appearance.wallpaperPictureOfTheDay != null) {
          Greeter.WallpaperPlugin = "org.kde.potd";
          "Greeter/Wallpaper/org.kde.potd/General" = {
            Provider = cfg.kscreenlocker.appearance.wallpaperPictureOfTheDay.provider;
            UpdateOverMeteredConnection =
              with cfg.kscreenlocker.appearance.wallpaperPictureOfTheDay;
              (lib.mkIf (updateOverMeteredConnection != null) (if updateOverMeteredConnection then 1 else 0));
          };
        })
        (lib.mkIf (cfg.kscreenlocker.appearance.wallpaperSlideShow != null) {
          Greeter.WallpaperPlugin = "org.kde.slideshow";
          "Greeter/Wallpaper/org.kde.slideshow/General" = {
            SlidePaths =
              with cfg.kscreenlocker.appearance.wallpaperSlideShow;
              (
                if ((builtins.isPath path) || (builtins.isString path)) then
                  (builtins.toString cfg.kscreenlocker.appearance.wallpaperSlideShow.path)
                else
                  (builtins.concatStringsSep "," cfg.kscreenlocker.appearance.wallpaperSlideShow.path)
              );
            SlideInterval = cfg.kscreenlocker.appearance.wallpaperSlideShow.interval;
          };
        })
        (lib.mkIf (cfg.kscreenlocker.appearance.wallpaperPlainColor != null) {
          Greeter.WallpaperPlugin = "org.kde.color";
          "Greeter/Wallpaper/org.kde.color/General".Color = cfg.kscreenlocker.appearance.wallpaperPlainColor;
        })

        (lib.mkIf (cfg.kscreenlocker.appearance.alwaysShowClock != null) {
          "Greeter/LnF/General".alwaysShowClock = cfg.kscreenlocker.appearance.alwaysShowClock;
        })
        (lib.mkIf (cfg.kscreenlocker.appearance.showMediaControls != null) {
          "Greeter/LnF/General".showMediaControls = cfg.kscreenlocker.appearance.showMediaControls;
        })

        (lib.mkIf (cfg.kscreenlocker.autoLock != null) { Daemon.Autolock = cfg.kscreenlocker.autoLock; })

        (lib.mkIf (cfg.kscreenlocker.lockOnResume != null) {
          Daemon.LockOnResume = cfg.kscreenlocker.lockOnResume;
        })

        (lib.mkIf (cfg.kscreenlocker.timeout != null) { Daemon.Timeout = cfg.kscreenlocker.timeout; })

        (lib.mkIf (cfg.kscreenlocker.passwordRequiredDelay != null) {
          Daemon.LockGrace = cfg.kscreenlocker.passwordRequiredDelay;
        })

        (lib.mkIf (cfg.kscreenlocker.passwordRequired != null) {
          Daemon.RequirePassword = cfg.kscreenlocker.passwordRequired;
        })

        (lib.mkIf (cfg.kscreenlocker.lockOnStartup != null) {
          Daemon.LockOnStart = cfg.kscreenlocker.lockOnStartup;
        })
      ]
    );
  };
}
