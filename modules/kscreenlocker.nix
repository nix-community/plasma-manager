{ config, pkgs, lib, ... }:
let
  cfg = config.programs.plasma;
  inherit (import ../lib/wallpapers.nix { inherit lib; }) wallpaperPictureOfTheDayType wallpaperSlideShowType;
in
{
  options.programs.plasma.kscreenlocker = {
    wallpaper = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png";
      description = ''
        The wallpaper for the lockscreen. Can be either be the path to an image file or a kpackage.
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
    wallpaperSlideShow = lib.mkOption {
      type = lib.types.nullOr wallpaperSlideShowType;
      default = null;
      example = { path = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/"; };
      description = ''
        Allows you to set wallpaper using the slideshow plugin. Needs the path
        to at least one directory.
      '';
    };
    wallpaperPlainColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "0,64,174,256";
      description = ''
        Allows you to set wallpaper using a plain color. Color is a comma-seperated R,G,B,A string. Alpha optional (default is 256).
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion =
          let
            wallpapers = with cfg.workspace; [ wallpaperSlideShow wallpaper wallpaperPictureOfTheDay wallpaperPlainColor ];
          in
          lib.count (x: x != null) wallpapers <= 1;
        message = "Can set only one of wallpaper, wallpaperSlideShow, wallpaperPictureOfTheDay, and wallpaperPlainColor for kscreenlocker.";
      }
    ];
    programs.plasma.configFile.kscreenlockerrc = (lib.mkMerge [
      (lib.mkIf (cfg.kscreenlocker.wallpaper != null) {
        Greeter.WallpaperPlugin = "org.kde.image";
        "Greeter/Wallpaper/org.kde.image/General".Image = (builtins.toString cfg.kscreenlocker.wallpaper);
      })
      (lib.mkIf (cfg.kscreenlocker.wallpaperPictureOfTheDay != null) {
        Greeter.WallpaperPlugin = "org.kde.potd";
        "Greeter/Wallpaper/org.kde.potd/General" = {
          Provider = cfg.kscreenlocker.wallpaperPictureOfTheDay.provider;
          UpdateOverMeteredConnection = with cfg.kscreenlocker.wallpaperPictureOfTheDay;
            (lib.mkIf (updateOverMeteredConnection != null) (if updateOverMeteredConnection then 1 else 0));
        };
      })
      (lib.mkIf (cfg.kscreenlocker.wallpaperSlideShow != null) {
        Greeter.WallpaperPlugin = "org.kde.slideshow";
        "Greeter/Wallpaper/org.kde.slideshow/General" = {
          SlidePaths = with cfg.kscreenlocker.wallpaperSlideShow;
            (if ((builtins.isPath path) || (builtins.isString path)) then
              (builtins.toString cfg.kscreenlocker.wallpaperSlideShow.path) else
              (builtins.concatStringsSep "," cfg.kscreenlocker.wallpaperSlideShow.path));
          SlideInterval = cfg.kscreenlocker.wallpaperSlideShow.interval;
        };
      })
      (lib.mkIf (cfg.kscreenlocker.wallpaperPlainColor != null) {
        Greeter.WallpaperPlugin = "org.kde.color";
        "Greeter/Wallpaper/org.kde.color/General".Color = cfg.kscreenlocker.wallpaperPlainColor;
      })
    ]);
  };
}
