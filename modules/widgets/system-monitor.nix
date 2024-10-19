{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

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
  toEscapedList =
    ids: if ids != null then "[${lib.concatMapStringsSep ", " (x: ''\"${x}\"'') ids}]" else null;

  mkListOption = mkOption {
    type = with types; nullOr (listOf str);
    default = null;
    apply = toEscapedList;
  };

  # {name, color} -> {name, value}
  # Convert the sensor attrset into a name-value pair expected by listToAttrs
  toColorKV =
    { name, color, ... }:
    {
      inherit name;
      value = color;
    };
  toLabelKV =
    { name, label, ... }:
    {
      inherit name;
      value = label;
    };
in
{
  systemMonitor = {
    description = "A system monitor widget.";

    opts = {
      # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/systemmonitor/systemmonitor/package/contents/config/main.xml for the accepted raw options

      position = mkOption {
        type = positionType;
        example = {
          horizontal = 250;
          vertical = 50;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 500;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      title = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "The title of this system monitor.";
      };
      showTitle = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Show or hide the title.";
      };
      showLegend = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "Show or hide the legend.";
      };
      displayStyle = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "org.kde.ksysguard.barchart";
        description = "The display style of the chart. Uses the internal plugin name.";
      };
      sensors = mkOption {
        type =
          with types;
          nullOr (
            listOf (submodule {
              options = {
                name = mkOption {
                  type = str;
                  example = "cpu/all/usage";
                  description = "The name of the sensor.";
                };
                color = mkOption {
                  type = str; # TODO maybe use a better type
                  example = "255,255,255";
                  description = "The color of the sensor, as a string containing 8-bit integral RGB values separated by commas";
                };
                label = mkOption {
                  type = str;
                  example = "CPU %";
                  description = "The label of the sensor.";
                };
              };
            })
          );
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
        apply =
          sensors:
          lib.optionalAttrs (sensors != null) {
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
        example = [
          "cpu/all/averageTemperature"
          "cpu/all/averageFrequency"
        ];
        description = ''
          The list of text-only sensors, displayed in the pop-up upon clicking the widget.
        '';
      };
      range = {
        from = mkOption {
          type = with lib.types; nullOr (ints.between 0 100);
          default = null;
          description = "The lower range the sensors can take.";
        };
        to = mkOption {
          type = with lib.types; nullOr (ints.between 0 100);
          default = null;
          description = "The upper range the sensors can take.";
        };
      };
      settings = mkOption {
        type = configValueType;
        default = null;
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };

    convert =
      {
        title,
        showTitle,
        showLegend,
        displayStyle,
        totalSensors,
        sensors,
        textOnlySensors,
        range,
        settings,
        ...
      }:
      {
        name = "org.kde.plasma.systemmonitor";
        config = lib.filterAttrsRecursive (_: v: v != null) (
          lib.recursiveUpdate {
            Appearance = {
              inherit title;
              inherit showTitle;
              chartFace = displayStyle;
            };
            Sensors = {
              lowPrioritySensorIds = textOnlySensors;
              totalSensors = totalSensors;
            };
            "org.kde.ksysguard.piechart/General" = {
              inherit showLegend;
              rangeAuto = (range.from == null && range.to == null);
              rangeFrom = range.from;
              rangeTo = range.to;
            };
          } (lib.recursiveUpdate sensors settings)
        );
      };
  };
}
