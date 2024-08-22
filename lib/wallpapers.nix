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

  # Values are taken from
  #  https://invent.kde.org/plasma/kdeplasma-addons/-/blob/bc53d651cf60709396c9229f8c582ec8a9d2ee53/applets/mediaframe/package/contents/ui/ConfigGeneral.qml#L148-170
  wallpaperFillModeTypes = {
    "Stretch" = 0; # a.k.a. Scaled
    "PreserveAspectFit" = 1; # a.k.a. Scaled Keep Proportions
    "PreserveAspectCrop" = 2; # a.k.a. Scaled And Cropped
    "Tile" = 3;
    "TileVertically" = 4;
    "TileHorizontally" = 5;
    "Pad" = 6; # a.k.a. Centered
  };
}
