{ config, lib, ... }:
let
  cfg = config.programs.plasma;

  powerButtonActions = {
    nothing = 0;
    sleep = 1;
    shutDown = 8;
    lockScreen = 32;
    showLogoutScreen = null;
    turnOffScreen = 64;
  };

  autoSuspendActions = {
    nothing = 0;
    sleep = null;
    shutDown = 8;
  };
in
{
  config.assertions = [
    {
      assertion = (cfg.powerdevil.autoSuspend.action != autoSuspendActions.nothing || cfg.powerdevil.autoSuspend.idleTimeout == null);
      message = "Setting programs.plasma.powerdevil.autoSuspend.idleTimeout for autosuspend-action \"nothing\" is not supported.";
    }
    {
      assertion = (cfg.powerdevil.turnOffDisplay.idleTimeout != -1 || cfg.powerdevil.turnOffDisplay.idleTimeoutWhenLocked == null);
      message = "Setting programs.plasma.powerdevil.turnOffDisplay.idleTimeoutWhenLocked for when idleTimeout is \"never\" is not supported.";
    }
  ];

  options = {
    programs.plasma.powerdevil = {
      powerButtonAction = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames powerButtonActions));
        default = null;
        example = "nothing";
        description = ''
          The action to perform when the power button is pressed.
        '';
        apply = action: if (action == null) then null else powerButtonActions."${action}";
      };
      autoSuspend = {
        action = lib.mkOption {
          type = with lib.types; nullOr (enum (builtins.attrNames autoSuspendActions));
          default = null;
          example = "nothing";
          description = ''
            The action to perform after a certain period of inactivity.
          '';
          apply = action: if (action == null) then null else autoSuspendActions."${action}";
        };
        idleTimeout = lib.mkOption {
          type = with lib.types; nullOr (ints.between 60 600000);
          default = null;
          example = 600;
          description = ''
            The duration (in seconds) the computer must be idle until the
            auto-suspend action is executed.
          '';
        };
      };
      turnOffDisplay = {
        idleTimeout = lib.mkOption {
          type = with lib.types; nullOr (either (enum [ "never" ]) (ints.between 30 600000));
          default = null;
          example = 300;
          description = ''
            The duration (in seconds) the computer must be idle (when unlocked)
            until the display turns off.
          '';
          apply = timeout:
            if (timeout == null) then null else
            if (timeout == "never") then -1
            else timeout;
        };
        idleTimeoutWhenLocked = lib.mkOption {
          type = with lib.types; nullOr (either (enum [ "whenLockedAndUnlocked" "immediately" ]) (ints.between 20 600000));
          default = null;
          example = 60;
          description = ''
            The duration (in seconds) the computer must be idle (when locked)
            until the display turns off.
          '';
          apply = timeout:
            if (timeout == null) then null else
            if (timeout == "whenLockedAndUnlocked") then -2 else
            if (timeout == "immediately") then 0
            else timeout;
        };
      };
    };
  };

  config.programs.plasma.configFile = lib.mkIf cfg.enable {
    powerdevilrc = lib.filterAttrs (k: v: v != null) {
      "AC/SuspendAndShutdown" = {
        PowerButtonAction = cfg.powerdevil.powerButtonAction;
        AutoSuspendAction = cfg.powerdevil.autoSuspend.action;
        AutoSuspendIdleTimeoutSec = cfg.powerdevil.autoSuspend.idleTimeout;
      };
      "AC/Display" = {
        TunOffDisplayIdleTimeoutSec = cfg.powerdevil.turnOffDisplay.idleTimeout;
        TunOffDisplayIdleTimeoutWhenLockedSec = cfg.powerdevil.turnOffDisplay.idleTimeoutWhenLocked;
      };
    };
  };
}
