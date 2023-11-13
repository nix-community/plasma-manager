# General workspace behavior settings:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.workspace = {
    clickItemTo = lib.mkOption {
      type = lib.types.enum [ "open" "select" ];
      default = "open";
      description = ''
        Clicking files or folders should open or select them.
      '';
    };

    tooltipDelay = lib.mkOption {
      type = lib.types.int;
      default = -1;
      example = 5;
      description = ''
        The delay in milliseconds before an element's tooltip is shown when hovered over.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = null;
      example = "breeze-dark";
      description = ''
        The Plasma theme.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.plasma.configFile.kdeglobals = {
        KDE.SingleClick = lib.mkDefault (cfg.workspace.clickItemTo == "open");
      };
    })
    (lib.mkIf (cfg.enable && cfg.workspace.tooltipDelay > 0) {
      programs.plasma.configFile.plasmarc = {
        PlasmaToolTips.Delay = cfg.workspace.tooltipDelay;
      };
    })
    (lib.mkIf (cfg.enable && cfg.workspace.theme != null) {
      programs.plasma.configFile.plasmarc = {
        Theme.name = cfg.workspace.theme;
      };
    })
  ];
}
