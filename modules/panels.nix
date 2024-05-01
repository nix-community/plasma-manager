{
  config,
  lib,
  ...
} @ args: let
  cfg = config.programs.plasma;

  widgets = import ./widgets args;

  panelType = lib.types.submodule ({config, ...}: {
    options = {
      height = lib.mkOption {
        type = lib.types.int;
        default = 32;
        description = "The height of the panel.";
      };
      offset = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 100;
        description = "The offset of the panel from the anchor-point.";
      };
      minLength = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 1000;
        description = "The minimum required length/width of the panel.";
      };
      maxLength = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 1600;
        description = "The maximum allowed length/width of the panel.";
      };
      lengthMode = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["fit" "fill" "custom"]);
        default = 
          if config.minLength != null || config.maxLength != null then
            "custom"
          else
            null;
        example = "fit";
        description = "(Plasma 6 only) The length mode of the panel. Defaults to `custom` if either `minLength` or `maxLength` is set.";
      };
      location = lib.mkOption {
        type = lib.types.str;
        default = lib.types.nullOr (lib.types.enum [ "top" "bottom" "left" "right" "floating" ]);
        example = "left";
        description = "The location of the panel.";
      };
      alignment = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "left" "center" "right" ]);
        default = "center";
        example = "right";
        description = "The alignment of the panel.";
      };
      hiding = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "none"
          "autohide"
          # Plasma 5 only
          "windowscover"
          "windowsbelow"
          # Plasma 6 only
          "dodgewindows"
          "normalpanel"
          "windowsgobelow"
        ]);
        default = null;
        example = "autohide";
        description = ''
          The hiding mode of the panel. Here windowscover and windowsbelow are
          plasma 5 only, while dodgewindows, windowsgobelow and normalpanel are
          plasma 6 only.
        '';
      };
      floating = lib.mkEnableOption "Enable or disable floating style (plasma 6 only).";
      widgets = lib.mkOption {
        type = with lib.types; listOf (either str widgets.type);
        default = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseperator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
        example = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseperator"
          "org.kde.plasma.digitalclock"
        ];
        description = ''
          The widgets to use in the panel. To get the names, it may be useful
          to look in the share/plasma/plasmoids folder of the nix-package the
          widget/plasmoid is from. Some packages which include some
          widgets/plasmoids are for example plasma-desktop and
          plasma-workspace.
        '';
      };
      screen = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "The screen the panel should appear on";
      };
      extraSettings = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Extra lines to add to the layout.js. See
          https://develop.kde.org/docs/plasma/scripting/ for inspiration.
        '';
      };
    };
  });

  # list of panels -> bool
  # Checks if any panels have non-default screens. If any of them do we need
  # some hacky tricks to place them on their screens.
  anyNonDefaultScreens = builtins.any (panel: panel.screen != 0);

  # any value or null -> string -> string 
  # If value is null, returns the empty string, otherwise returns the provided string
  stringIfNotNull = v: lib.optionalString (v != null);

  # string -> string
  # Wrap a string in double quotes.
  wrapInQuotes = s: ''"${s}"'';

  # list of strings -> string
  # Converts a list of strings to a single string, that can be parsed as a string list in JavaScript
  toJSStringList = values: ''[${lib.concatMapStringsSep ", " wrapInQuotes values}]'';

  # Generate writeConfig calls to include for a widget with additional
  # configurations.
  genWidgetConfigStr = widget: group: key: value:
    ''
      var w = panelWidgets["${widget}"];
      w.currentConfigGroup = ${toJSStringList (lib.splitString "/" group)};
      w.writeConfig("${key}", ${
        if builtins.isString value then 
          wrapInQuotes value 
        else
          toJSStringList value 
      });
    '';
  # Generate the text for all of the configuration for a widget with additional
  # configurations.
  widgetConfigsToStr = widget: config: lib.pipe config [
    (lib.mapAttrsToList
      (group: lib.mapAttrsToList (genWidgetConfigStr widget group))
    )
    lib.concatLists
    (lib.concatStringsSep "\n")
  ];

  #
  # Functions to aid us creating a single panel in the layout.js
  #
  plasma6OnlyCmd = cmd: ''
    if (applicationVersion.split(".")[0] == 6) {
      ${cmd}
    }
  '';

  panelAddWidgetStr = widget: let
    widget' = widgets.convert widget;
    createWidget = name: ''panelWidgets["${name}"] = panel.addWidget("${name}");'';
  in
    if builtins.isString widget
    then createWidget widget
    else
      ''
        ${createWidget widget'.name}
        ${stringIfNotNull widget'.config (widgetConfigsToStr widget'.name widget'.config)}
      '';

  panelToLayout = panel: let
    inherit (lib) boolToString optionalString;
    inherit (builtins) toString;
  in ''
    var panel = new Panel;
    panel.height = ${toString panel.height};
    panel.floating = ${boolToString panel.floating};
    ${stringIfNotNull panel.alignment ''panel.alignment = "${panel.alignment}";''}
    ${stringIfNotNull panel.hiding ''panel.hiding = "${panel.hiding}";''}
    ${stringIfNotNull panel.location ''panel.location = "${panel.location}";''}
    ${stringIfNotNull panel.lengthMode (plasma6OnlyCmd ''panel.lengthMode = "${panel.lengthMode}";'')}
    ${stringIfNotNull panel.maxLength "panel.maximumLength = ${toString panel.maxLength};"}
    ${stringIfNotNull panel.minLength "panel.minimumLength = ${toString panel.minLength};"}
    ${stringIfNotNull panel.offset "panel.offset = ${toString panel.offset};"}
    ${optionalString (panel.screen != 0) ''panel.writeConfig("lastScreen[$i]", ${toString panel.screen});''}

    var panelWidgets = {};
    ${lib.concatMapStringsSep "\n" panelAddWidgetStr panel.widgets}

    ${stringIfNotNull panel.extraSettings panel.extraSettings}
  '';
in
{
  options.programs.plasma.panels = lib.mkOption {
    type = lib.types.listOf panelType;
    default = [ ];
  };

  config = lib.mkIf (cfg.enable && (lib.length cfg.panels) > 0) {
    programs.plasma.startup.desktopScript."apply_panels" = {
      preCommands = ''
        # We delete plasma-org.kde.plasma.desktop-appletsrc to hinder it
        # growing indefinitely. See:
        # https://github.com/pjones/plasma-manager/issues/76
        [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ] && rm ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
      '';
      text = ''
        // Removes all existing panels
        panels().forEach((panel) => panel.remove());

        // Adds the panels
        ${lib.concatMapStringsSep "\n" panelToLayout config.programs.plasma.panels}
      '';
      postCommands = lib.mkIf (anyNonDefaultScreens cfg.panels) ''
        if [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ]; then
          sed -i 's/^lastScreen\\x5b$i\\x5d=/lastScreen[$i]=/' ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
          # We sleep a second in order to prevent some bugs (like the incorrect height being set)
          sleep 1; nohup plasmashell --replace &
        fi
      '';
      priority = 2;
    };
  };
}

