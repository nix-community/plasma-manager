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
  panelSpacer = {
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
      expanding = mkBoolOption "Whether the spacer should expand to fill the available space.";
      length = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 50;
        description = ''
          The length of the spacer.
          If expanding is set to true, this value is ignored.
        '';
      };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            expanding = true;
          };
        };
        description = ''
          Extra configuration for the widget
        '';
        apply = settings: if settings == null then { } else settings;
      };
    };

    convert =
      {
        expanding,
        length,
        settings,
        ...
      }:
      {
        name = "org.kde.plasma.panelspacer";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) { inherit expanding length; };
        } settings;
      };
  };
}
