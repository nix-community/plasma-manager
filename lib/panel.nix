{ lib, config, ... }:
let
  widgets = (import ../modules/widgets { inherit lib; });
  panelToLayout = panel:
    let
      inherit (widgets.lib) addWidgetStmts stringIfNotNull;
      inherit (lib) boolToString optionalString;
      inherit (builtins) toString;

      plasma6OnlyCmd = cmd: ''
        if (isPlasma6) {
          ${cmd}
        }
      '';
    in
    ''
      {
        const panel = new Panel();
        panel.height = ${toString panel.height};
        panel.floating = ${boolToString panel.floating};
        ${stringIfNotNull panel.alignment ''panel.alignment = "${panel.alignment}";''}
        ${stringIfNotNull panel.hiding ''panel.hiding = "${panel.hiding}";''}
        ${stringIfNotNull panel.location ''panel.location = "${panel.location}";''}
        ${stringIfNotNull panel.lengthMode (plasma6OnlyCmd ''panel.lengthMode = "${panel.lengthMode}";'')}
        ${stringIfNotNull panel.maxLength "panel.maximumLength = ${toString panel.maxLength};"}
        ${stringIfNotNull panel.minLength "panel.minimumLength = ${toString panel.minLength};"}
        ${stringIfNotNull panel.offset "panel.offset = ${toString panel.offset};"}
        ${optionalString (panel.screen != null) ''panel.writeConfig("lastScreen[$i]", ${toString panel.screen});''}

        ${addWidgetStmts "panel" "panelWidgets" panel.widgets}
        ${stringIfNotNull panel.extraSettings panel.extraSettings}
      }
    '';
in
''
  // Removes all existing panels
  panels().forEach((panel) => panel.remove());

  const isPlasma6 = applicationVersion.split(".")[0] == 6;

  // Adds the panels
  ${lib.concatMapStringsSep "\n" panelToLayout config.programs.plasma.panels}
''
