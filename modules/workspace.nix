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
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.files.kdeglobals = {
      KDE.SingleClick = lib.mkDefault (cfg.workspace.clickItemTo == "open");
    };
  };
}
