{ lib, widgets, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  fontType = types.submodule {
    options = {
      family = mkOption {
        type = types.str;
        example = "Noto Sans";
        description = "The family of the font.";
      };
      bold = mkEnableOption "bold text";
      italic = mkEnableOption "italic text";
      weight = mkOption {
        type = types.ints.between 1 1000;
        default = 50;
        description = "The weight of the font.";
      };
      style = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The custom style of the font.";
      };
      size = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "The size of the font.";
      };
    };
  };

  enums = {
    date = {
      format = [ "shortDate" "longDate" "isoDate" ];
      position = [ "adaptive" "besideTime" "belowTime" ];
    };
    time = {
      showSeconds = [ "never" "onlyInTooltip" "always" ];
      format = [ "12h" "default" "24h" ];
    };
    timeZone.format = [ "code" "city" "offset" ];
    calendar.weekdays = [ "sunday" "monday" "tuesday" "wednesday" "thursday" "friday" "saturday" ];
  };
in
{
  digitalClock = {
    description = "A digital clock widget.";

    opts = {
      # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/digital-clock/package/contents/config/main.xml for the accepted raw options

      date = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Enable showing the current date.";
        };

        format = mkOption {
          type = types.nullOr (types.either (types.enum enums.date.format) (types.submodule {
            options.custom = mkOption {
              type = types.str;
              example = "ddd d";
              description = "The custom date format to use.";
            };
          }));
          default = null;
          example = { custom = "d.MM.yyyy"; };
          description = ''
            The date format used for this clock.

            Could be as a short date, long date, a ISO 8601 date (yyyy-mm-dd), or a custom date format.
            Short and long date formats are locale-dependent.
          '';
        };

        position = mkOption {
          type = types.nullOr (types.enum enums.date.position);
          default = null;
          description = ''
            The position where the date is displayed.

            Could be adaptive, always beside the displayed time, or below the displayed time.
          '';
        };
      };

      time = {
        showSeconds = mkOption {
          type = types.nullOr (types.enum enums.time.showSeconds);
          default = null;
          description = ''
            When and where the seconds should be shown on the clock.

            Could be never, only in the tooltip on hover, or always.
          '';
        };
        format = mkOption {
          type = types.nullOr (types.enum enums.time.format);
          default = null;
          description = ''
            The time format used for this clock.

            Could be 12-hour, the default for your locale, or 24-hour.
          '';
        };
      };

      timeZone = {
        selected = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ "Europe/Berlin" "Asia/Shanghai" ];
          description = ''
            The timezones that are configured for this clock.

            The special value "Local" indicates the system's current timezone.
          '';
        };
        lastSelected = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The timezone to show upon widget restore.

            The special value "Local" indicates the system's current timezone.
          '';
        };
        changeOnScroll = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Allow changing the displayed timezone by scrolling on the widget with the mouse wheel.";
        };
        format = mkOption {
          type = types.nullOr (types.enum enums.timeZone.format);
          default = null;
          example = "code";
          description = ''
            The format of the timezone displayed, whether as a
            code, full name of the city that the timezone belongs to,
            or as an UTC offset.

            For example, for the timezone Asia/Shanghai, the three formats
            listed above would display "CST", "Shanghai" and "+8" respectively.
          '';
        };
        alwaysShow = mkEnableOption "always showing the selected timezone, when it's the same with the system timezone";
      };

      calendar = {
        firstDayOfWeek = mkOption {
          type = types.nullOr (types.enum enums.calendar.weekdays);
          default = null;
          example = "monday";
          description = ''
            The first day of the week that the calendar uses.

            If null, then the default for the user locale is used.
          '';
        };
        plugins = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "List of enabled calendar plugins, where additional event data can be sourced from.";
        };
        showWeekNumbers = mkEnableOption "showing week numbers in the calendar";
      };

      font = mkOption {
        type = types.nullOr fontType;
        default = null;
        example = {
          family = "Noto Sans";
          bold = true;
          size = 16;
        };
        description = ''
          The font used for this clock.

          If null, then it will use the system font and automatically expand to fill available space.
        '';
      };
    };

    convert =
      { date ? {}
      , time ? {}
      , timeZone ? {}
      , calendar ? {}
      , font ? null
      ,
      }:
      let
        inherit (builtins) toString;
        inherit (widgets.lib) boolToString' getEnum;

        isDateFormatCustom = date ? format && date.format ? custom;
      in
      {
        name = "org.kde.plasma.digitalclock";
        config.Appearance = lib.filterAttrs (_: v: v != null) (
          {
            showDate = boolToString' (date.enable or null);
            dateDisplayFormat = getEnum enums.date.position (date.position or null);
            dateFormat = if isDateFormatCustom then "custom" else date.format or null;
            customDateFormat = if isDateFormatCustom then date.format.custom else null;

            showSeconds = getEnum enums.time.showSeconds (time.showSeconds or null);
            use24hFormat = getEnum enums.time.format (time.format or null);

            selectedTimeZones = timeZone.selected or null;
            lastSelectedTimezone = timeZone.lastSelected or null;
            wheelChangesTimezone = boolToString' (timeZone.changeOnScroll or null);
            displayTimezoneFormat = getEnum enums.timeZone.format (timeZone.format or null);
            showLocalTimezone = boolToString' (timeZone.alwaysShow or null);

            firstDayOfWeek = getEnum enums.calendar.weekdays (calendar.firstDayOfWeek or null);
            enabledCalendarPlugins = calendar.plugins or null;

            autoFontAndSize = boolToString' (font == null);
          }
          // lib.optionalAttrs (font != null) {
            fontFamily = font.family;
            boldText = boolToString' font.bold;
            italicText = boolToString' font.italic;
            fontWeight = toString font.weight;
            fontStyleName = font.styleName;
            fontSize = toString font.size;
          }
        );
      };
  };
}
