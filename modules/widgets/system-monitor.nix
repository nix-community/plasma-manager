{ lib, ... }:
let
  inherit (lib) mkOption types;

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

  mkListOption = mkOption {
    type = types.nullOr (types.listOf types.str);
    default = null;
    apply = toEscapedList;
  };

  # {name, color} -> {name, value}
  # Convert the sensor attrset into a name-value pair expected by listToAttrs
  toColorKV =
    { name
    , color
    , label
    ,
    }: {
      inherit name;
      value = color;
    };
  toLabelKV =
    { name
    , color
    , label
    ,
    }: {
      inherit name;
      value = label;
    };
in
{
  systemMonitor = {
    description = "A system monitor widget.";

    opts = {
      # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/systemmonitor/systemmonitor/package/contents/config/main.xml for the accepted raw options 

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
            label = mkOption {
              type = types.str;
              example = "CPU %";
              description = "The label of the sensor.";
            };
          };
        }));
        default = null;
        example = [
          {
            name = "gpu/gpu1/usage";
            color = "180,190,254";
            label = "GPU %";
          }
        ];
        description = ''
          The list of sensors displayed as a part of the graph/chart.
        '';
        apply = sensors: lib.optionalAttrs (sensors != null) {
          SensorColors = builtins.listToAttrs (map toColorKV sensors);
          SensorLabels = builtins.listToAttrs (map toLabelKV sensors);
          Sensors.highPrioritySensorIds = toEscapedList (map (s: s.name) sensors);
        };
      };

      totalSensors = mkListOption // {
        example = [ "cpu/all/usage" ];
        description = ''
          The list of "total sensors" displayed on top of the graph/chart.
        '';
      };
      textOnlySensors = mkListOption // {
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
      }: {
        name = "org.kde.plasma.systemmonitor";
        config = lib.filterAttrsRecursive (_: v: v != null) (lib.recursiveUpdate
          {
            Appearance = {
              inherit title;
              chartFace = displayStyle;
            };
            Sensors = {
              lowPrioritySensorIds = textOnlySensors;
              totalSensors = totalSensors;
            };
          }
          sensors);
      };
  };
}
