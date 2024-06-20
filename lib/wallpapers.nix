{ lib, ... }:
{
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
}
