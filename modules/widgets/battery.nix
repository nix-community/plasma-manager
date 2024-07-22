{ lib, ... }: {
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
      extraConfig = lib.mkOption {
        type = with lib.types; nullOr (attrsOf (attrsOf (either (oneOf [ bool float int str ]) (listOf (oneOf [ bool float int str ])))));
        default = null;
        example = {
          General = {
            showPercentage = true;
          };
        };
        apply = extraConfig: if extraConfig == null then {} else extraConfig;
      };
    };

    convert = { showPercentage, extraConfig }: {
      name = "org.kde.plasma.battery";
      config = lib.recursiveUpdate {
        General = lib.filterAttrs (_: v: v != null) {
          inherit showPercentage;
        };
      } extraConfig;
    };
  };
}
