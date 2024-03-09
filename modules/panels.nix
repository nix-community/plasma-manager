{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;

  # Widget types
  widgetType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "org.kde.plasma.kickoff";
        description = "The name of the widget to add.";
      };
      config = lib.mkOption {
        type = with lib.types; nullOr (attrsOf (attrsOf (either str (listOf str))));
        default = null;
        example = {
          General.icon = "nix-snowflake-white";
        };
        description = "Extra configuration-options for the widget.";
      };
    };
  };

  panelType = lib.types.submodule {
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
        type = with lib.types; listOf (either str widgetType);
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
      extraSettings = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Extra lines to add to the layout.js. See
          https://develop.kde.org/docs/plasma/scripting/ for inspiration.
        '';
      };
    };
  };

  #
  # Functions to generate layout.js configurations from the widgetType
  #
  # Configgroups must be javascript lists.
  widgetConfigGroupFormat = group: ''[${lib.concatStringsSep ", " (map (s: "\"${s}\"") (lib.splitString "." group))}]'';
  # If the specified value is a string then add in extra quotes. If we have a
  # list, convert this to a javascript list.
  widgetConfigValueFormat = value: if (builtins.isString value) then "\"${value}\"" else ''[${(lib.concatStringsSep ", " (map (s: "\"${s}\"") value))}]'';
  # Generate writeConfig calls to include for a widget with additional
  # configurations.
  genWidgetConfigStr = widget: group: key: value:
    ''
      var w = panelWidgets["${widget}"]
      w.currentConfigGroup = ${widgetConfigGroupFormat group}
      w.writeConfig("${key}", ${widgetConfigValueFormat value})
    '';
  # Generate the text for all of the configuration for a widget with additional
  # configurations.
  widgetConfigsToStr = widget: config:
    lib.concatStringsSep "\n"
      (lib.concatLists
        (lib.mapAttrsToList
          (group: groupAttrs:
            (lib.mapAttrsToList (key: value: (genWidgetConfigStr widget group key value)) groupAttrs))
          config));

  #
  # Functions to aid us creating a single panel in the layout.js
  #
  plasma6OnlyCmd = cmd: ''
    if (applicationVersion.split(".")[0] == 6) {
      ${cmd}
    }
  '';
  panelWidgetCreationStr = widget: ''panelWidgets["${widget}"] = panel.addWidget("${widget}")'';
  panelAddWidgetStr = widget: if (builtins.isString widget) then (panelWidgetCreationStr widget) else
  ''
    ${panelWidgetCreationStr widget.name}
    ${if widget.config == null then "" else (widgetConfigsToStr widget.name widget.config)}
  '';
  panelAddWidgetsStr = panel: lib.concatStringsSep "\n" (map panelAddWidgetStr panel.widgets);
  panelToLayout = panel: ''

    var panel = new Panel;
    panel.height = ${builtins.toString panel.height}
    panel.floating = ${lib.boolToString panel.floating}
    var panelWidgets = {}
    ${if panel.alignment != null then "panel.alignment = \"${panel.alignment}\"" else ""}
    ${if panel.hiding != null then "panel.hiding = \"${panel.hiding}\"" else ""}
    ${if panel.location != null then "panel.location = \"${panel.location}\"" else ""}
    ${if panel.maxLength != null || panel.minLength != null then (plasma6OnlyCmd "panel.lengthMode = \"custom\"") else ""}
    ${if panel.maxLength != null then "panel.maximumLength = ${builtins.toString panel.maxLength}" else ""}
    ${if panel.minLength != null then "panel.minimumLength = ${builtins.toString panel.minLength}" else ""}
    ${if panel.offset != null then "panel.offset = ${builtins.toString panel.offset}" else ""}
    ${panelAddWidgetsStr panel}
    ${if panel.extraSettings != null then panel.extraSettings else ""}
  '';

  # Generates the text for the full layout.js, combining the configuration for
  # all the single panels into one.
  panelsToLayoutJS = panels: lib.concatStringsSep "\n" (map panelToLayout panels);
in
{
  options.programs.plasma.panels = lib.mkOption {
    type = lib.types.listOf panelType;
    default = [ ];
  };

  config = mkIf (cfg.enable && (lib.length cfg.panels) > 0) {
    programs.plasma.startup.dataFile."layout.js" = ''
      // Removes all existing panels
      var allPanels = panels();
      for (var panelIndex = 0; panelIndex < allPanels.length; panelIndex++) {
        var p = allPanels[panelIndex];
        p.remove();
      }

      // Adds the panels
      ${panelsToLayoutJS config.programs.plasma.panels}
    '';

    # Very similar to applying themes, we keep track of the last time the panel
    # was generated successfully, and run this only once per generation (granted
    # everything succeeds and we are not using overrideConfig).
    programs.plasma.startup.autoStartScript."apply_layout" = {
      text = ''
        layout_file="${config.xdg.dataHome}/plasma-manager/${cfg.startup.dataDir}/layout.js"
        last_update="$(sha256sum $layout_file)"
        last_update_file=${config.xdg.dataHome}/plasma-manager/last_run_layouts
        if [ -f "$last_update_file" ]; then
          stored_last_update=$(cat "$last_update_file")
        fi

        if ! [ "$last_update" = "$stored_last_update" ]; then
          # We delete plasma-org.kde.plasma.desktop-appletsrc to hinder it
          # growing indefinitely. See:
          # https://github.com/pjones/plasma-manager/issues/76
          [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ] && rm ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc

          # And finally apply the layout.js
          success=1
          qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat $layout_file)" || success=0
          [ $success -eq 1 ] && echo "$last_update" > "$last_update_file"
        fi
      '';
      # Setting up the panels should happen after setting the theme as the theme
      # may overwrite some settings (like the kickoff-icon)
      priority = 2;
    };
  };
}

