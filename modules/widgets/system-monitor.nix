{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  systemMonitor = {
    description = "A system monitor widget.";

    opts = {
      title = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The title of this system monitor.";
      };
      displayStyle = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.kde.ksysguard.barchart";
        description = "The display style of the chart. Uses the internal plugin name.";
      };
      sensors = mkOption {
        type = types.nullOr (types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              example = "cpu/all/usage";
              description = "The name of the sensor.";
            };
            color = mkOption {
              type = types.str; # TODO maybe use a better type
              example = "255,255,255";
              description = "The color of the sensor, as a string containing 8-bit integral RGB values separated by commas";
            };
          };
        }));
        default = null;
        example = [
          {
            name = "gpu/gpu1/usage";
            color = "180,190,254";
          }
        ];
        description = ''
          The list of sensors displayed as a part of the graph/chart.
        '';
      };

      totalSensors = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [ "cpu/all/usage" ];
        description = ''
          The list of "total sensors" displayed on top of the graph/chart.
        '';
      };
      textOnlySensors = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [ "cpu/all/averageTemperature" "cpu/all/averageFrequency" ];
        description = ''
          The list of text-only sensors, displayed in the pop-up upon clicking the widget.
        '';
      };
    };

    convert =
      { title
      , displayStyle
      , totalSensors
      , sensors
      , textOnlySensors
      ,
      }:
      let
        # KDE expects a key/value pair like this:
        # ```ini
        # highPrioritySensorIds=["cpu/all/usage", "cpu/all/averageTemperature"]
        # ```
        #
        # Which is **different** to what would happen if you pass a list of strings to the JS script:
        # ```ini
        # highPrioritySensorIds=cpu/all/usage,cpu/all/averageTemperature
        # ```
        #
        # So, to satisfy the expected format we must quote the ENTIRE string as a valid JS string,
        # which means constructing a string that looks like this in the source code:
        # "[\"cpu/all/usage\", \"cpu/all/averageTemperature\"]"
        toEscapedList = ids:
          if ids != null
          then "[${lib.concatMapStringsSep ", " (x: ''\"${x}\"'') ids}]"
          else null;

        # {name, color} -> {name, value}
        # Convert the sensor attrset into a name-value pair expected by listToAttrs
        toColorKV =
          { name
          , color
          ,
          }: {
            inherit name;
            value = color;
          };
      in
      {
        name = "org.kde.plasma.systemmonitor";
        config = lib.filterAttrsRecursive (_: v: v != null) {
          Appearance = {
            inherit title;
            chartFace = displayStyle;
          };
          SensorColors =
            if sensors != null
            then builtins.listToAttrs (map toColorKV sensors)
            else null;
          Sensors = {
            highPrioritySensorIds =
              if sensors != null
              then toEscapedList (map (s: s.name) sensors)
              else null;
            lowPrioritySensorIds = toEscapedList textOnlySensors;
            totalSensors = toEscapedList totalSensors;
          };
        };
      };
  };
}
