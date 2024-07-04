{ lib, widgets, ... }:
let
  inherit (lib) mkOption types;
  inherit (widgets.lib) mkBoolOption mkEnumOption boolToString';

  fontType = types.submodule {
    options = {
      family = mkOption {
        type = types.str;
        example = "Noto Sans";
        description = "The family of the font.";
      };
      bold = mkBoolOption "Enable bold text.";
      italic = mkBoolOption "Enable italic text.";
      weight = mkOption {
        type = types.ints.between 1 1000;
        default = 50;
        description = "The weight of the font.";
        apply = builtins.toString;
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
        apply = builtins.toString;
      };
    };
  };
in
{
  digitalClock = {
    description = "A digital clock widget.";

    opts = {
      # See https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/digital-clock/package/contents/config/main.xml for the accepted raw options

      date = {
        enable = mkBoolOption "Enable showing the current date.";

        format =
          let
            enum = [ "ShortDate" "LongDate" "IsoDate" ];
          in
          mkOption {
            type = types.nullOr (types.either (types.enum enum) (types.submodule {
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
            apply = f:
              if f == null then
                { }
              else if f ? custom then
                {
                  dateFormat = "custom";
                  customDateFormat = f.custom;
                }
              else
                { dateFormat = f; };

          };

        position = mkEnumOption [ "Adaptive" "BesideTime" "BelowTime" ] // {
          example = "BelowTime";
          description = ''
            The position where the date is displayed.

            Could be adaptive, always beside the displayed time, or below the displayed time.
          '';
        };
      };

      time = {
        showSeconds = mkEnumOption [ "Never" "OnlyInTooltip" "Always" ] // {
          example = "Always";
          description = ''
            When and where the seconds should be shown on the clock.

            Could be never, only in the tooltip on hover, or always.
          '';
        };
        format = mkEnumOption [ "12h" "Default" "24h" ] // {
          example = "24h";
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
        changeOnScroll = mkBoolOption "Allow changing the displayed timezone by scrolling on the widget with the mouse wheel.";
        format = mkEnumOption [ "Code" "City" "Offset" ] // {
          example = "Code";
          description = ''
            The format of the timezone displayed, whether as a
            code, full name of the city that the timezone belongs to,
            or as an UTC offset.

            For example, for the timezone Asia/Shanghai, the three formats
            listed above would display "CST", "Shanghai" and "+8" respectively.
          '';
        };
        alwaysShow = mkBoolOption "Always show the selected timezone, when it's the same with the system timezone";
      };

      calendar = {
        firstDayOfWeek = mkEnumOption [ "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" ] // {
          example = "Monday";
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
        showWeekNumbers = mkBoolOption "Enable showing week numbers in the calendar";
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
        apply = font:
          {
            autoFontAndSize = boolToString' (font == null);
          }
          // lib.optionalAttrs (font != null) {
            fontFamily = font.family;
            boldText = font.bold;
            italicText = font.italic;
            fontWeight = font.weight;
            fontStyleName = font.style;
            fontSize = font.size;
          };
      };
    };

    convert =
      { date
      , time
      , timeZone
      , calendar
      , font
      }: {
        name = "org.kde.plasma.digitalclock";
        config.Appearance = lib.filterAttrs (_: v: v != null) (
          {
            showDate = date.enable;
            dateDisplayFormat = date.position;

            showSeconds = time.showSeconds;
            use24hFormat = time.format;

            selectedTimeZones = timeZone.selected;
            lastSelectedTimezone = timeZone.lastSelected;
            wheelChangesTimezone = timeZone.changeOnScroll;
            displayTimezoneFormat = timeZone.format;
            showLocalTimezone = timeZone.alwaysShow;

            firstDayOfWeek = calendar.firstDayOfWeek;
            enabledCalendarPlugins = calendar.plugins;
            showWeekNumbers = calendar.showWeekNumbers;
          }
          // date.format
          // font
        );
      };
  };
}
