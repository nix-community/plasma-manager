{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
in {
  battery = {
    description = "The battery indicator widget.";

    # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/batterymonitor/package/contents/config/main.xml for the accepted raw options
    opts = {
      showPercentage = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Enable to show the battery percentage as a small label over the battery icon.";
      };
      settings = lib.mkOption {
        type = types.nullOr configValueType;
        default = null;
        example = {
          General = {
            showPercentage = true;
          };
        };
        apply = settings: if settings == null then {} else settings;
      };
    };

    convert = { showPercentage, settings }: {
      name = "org.kde.plasma.battery";
      config = lib.recursiveUpdate {
        General = lib.filterAttrs (_: v: v != null) {
          inherit showPercentage;
        };
      } settings;
    };
  };
}
