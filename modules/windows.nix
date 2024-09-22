# Window configuration:
{ config, lib, ... }:

let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.windows = {
    allowWindowsToRememberPositions = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        Allow apps to remember the positions of their own windows, if
        they support it.
      '';
    };
  };

  config = (
    lib.mkIf (cfg.enable && cfg.windows.allowWindowsToRememberPositions != null) {
      programs.plasma.configFile = {
        kdeglobals = {
          General.AllowKDEAppsToRememberWindowPositions = cfg.windows.allowWindowsToRememberPositions;
        };
      };
    }
  );
}
