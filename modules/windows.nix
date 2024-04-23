# Window configuration:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.windows = {
    allowWindowsToRememberPositions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow apps to remember the positions of their own windows, if
        they support it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.configFile = {
      kdeglobals = {
        General.AllowKDEAppsToRememberWindowPositions =
          lib.mkDefault cfg.windows.allowWindowsToRememberPositions;
      };
    };
  };
}

