{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  mkBoolOption =
    description:
    lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      inherit description;
    };
in
{
  appMenu = {
    opts = {
      position = lib.mkOption {
        type = positionType;
        example = {
          horizontal = 100;
          vertical = 300;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = lib.mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 50;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      compactView = mkBoolOption "Whether to show the app menu in a compact view";
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          Appearance = {
            compactView = true;
          };
        };
        description = ''
          Extra configuration for the widget
        '';
        apply = settings: if settings == null then { } else settings;
      };
    };

    convert =
      { compactView, settings, ... }:
      {
        name = "org.kde.plasma.appmenu";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) { inherit compactView; };
        } settings;
      };
  };
}
