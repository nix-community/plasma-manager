{ config, lib, ... }:
let
  cfg = config.programs.plasma;

  # Values can be found at:
  # https://github.com/KDE/powerdevil/blob/master/daemon/powerdevilenums.h
  powerButtonActions = {
    nothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
    lockScreen = 32;
    showLogoutScreen = 16;
    turnOffScreen = 64;
  };

  autoSuspendActions = {
    nothing = 0;
    hibernate = 2;
    sleep = 1;
    shutDown = 8;
  };

  whenSleepingEnterActions = {
    standby = 1;
    hybridSleep = 2;
    standbyThenHibernate = 3;
  };

  whenLaptopLidClosedActions = {
    doNothing = 0;
    sleep = 1;
    hibernate = 2;
    shutdown = 8;
    lockScreen = 32;
    turnOffScreen = 64;
  };

  # Since AC and battery allows the same options we create a function here which
  # can generate the options by just specifying the type (i.e. "AC" or
  # "battery").
  createPowerDevilOptions = type: {
    suspendSession = {
      autoSuspend = {
        action = lib.mkOption {
          type = with lib.types; nullOr (enum (builtins.attrNames autoSuspendActions));
          default = null;
          example = "nothing";
          description = ''
            The action, when on ${type}, to perform after a certain period of inactivity.
          '';
          apply = action: if (action == null) then null else autoSuspendActions."${action}";
        };
        idleTimeout = lib.mkOption {
          type = with lib.types; nullOr (ints.between 60 600000);
          default = null;
          example = 600;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            until the auto-suspend action is executed.
          '';
        };
      };

      powerButtonAction = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames powerButtonActions));
        default = null;
        example = "nothing";
        description = ''
          The action, when on ${type}, to perform when the power button is pressed.
        '';
        apply = action: if (action == null) then null else powerButtonActions."${action}";
      };

      whenLaptopLidClosed = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames whenLaptopLidClosedActions));
        default = null;
        example = "shutdown";
        description = ''
          The action, when on ${type}, to perform when the laptop lid is closed.
        '';
        apply = action: if (action == null) then null else whenLaptopLidClosedActions."${action}";
      };

      inhibitLidActionWhenExternalMonitorConnected = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          If enabled, the lid action will be inhibited when an external monitor is connected.
        '';
      };

      whenSleepingEnter = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames whenSleepingEnterActions));
        default = null;
        example = "standbyThenHibernate";
        description = ''
          The state, when on ${type}, to enter when sleeping.
        '';
        apply = action: if (action == null) then null else whenSleepingEnterActions."${action}";
      };
    };

    displayAndBrightness = {
      changeScreenBrightness = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = true;
          description = "Enable or disable screen brightness changing.";
        };
        percentage = lib.mkOption {
          type = with lib.types; nullOr (ints.between 0 100);
          default = null;
          example = 70;
          description = ''
            The screen brightness percentage when on ${type}.
          '';
        };
      };

      dimDisplay = {
        enable = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = "Enable or disable screen dimming.";
        };
        idleTimeout = lib.mkOption {
          type = with lib.types; nullOr (ints.between 20 600000);
          default = null;
          example = 300;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            until the display starts dimming.
          '';
        };
      };

      turnOffDisplay = {
        idleTimeout = lib.mkOption {
          type = with lib.types; nullOr (either (enum [ "never" ]) (ints.between 30 600000));
          default = null;
          example = 300;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            (when unlocked) until the display turns off.
          '';
          apply =
            timeout:
            if (timeout == null) then
              null
            else if (timeout == "never") then
              -1
            else
              timeout;
        };
        idleTimeoutWhenLocked = lib.mkOption {
          type =
            with lib.types;
            nullOr (
              either (enum [
                "whenLockedAndUnlocked"
                "immediately"
              ]) (ints.between 20 600000)
            );
          default = null;
          example = 60;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            (when locked) until the display turns off.
          '';
          apply =
            timeout:
            if (timeout == null) then
              null
            else if (timeout == "whenLockedAndUnlocked") then
              -2
            else if (timeout == "immediately") then
              0
            else
              timeout;
        };
      };
    };

    otherSettings = {};
  };

  # By the same logic as createPowerDevilOptions, we can generate the
  # configuration. cfgSectName is here the name of the section in powerdevilrc,
  # while optionsName is the name of the "namespace" where we should draw the
  # options from (i.e. powerdevil.AC or powerdevil.battery).
  createPowerDevilConfig = cfgSectName: optionsName: {
    "${cfgSectName}/SuspendAndShutdown" = {
      PowerButtonAction = cfg.powerdevil.${optionsName}.suspendSession.powerButtonAction;
      AutoSuspendAction = cfg.powerdevil.${optionsName}.suspendSession.autoSuspend.action;
      AutoSuspendIdleTimeoutSec = cfg.powerdevil.${optionsName}.suspendSession.autoSuspend.idleTimeout;
      SleepMode = cfg.powerdevil.${optionsName}.suspendSession.whenSleepingEnter;
      LidAction = cfg.powerdevil.${optionsName}.suspendSession.whenLaptopLidClosed;
      InhibitLidActionWhenExternalMonitorPresent =
        cfg.powerdevil.${optionsName}.suspendSession.inhibitLidActionWhenExternalMonitorConnected;
    };
    "${cfgSectName}/Display" = {
      TurnOffDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.displayAndBrightness.turnOffDisplay.idleTimeout;
      TurnOffDisplayIdleTimeoutWhenLockedSec =
        cfg.powerdevil.${optionsName}.displayAndBrightness.turnOffDisplay.idleTimeoutWhenLocked;
      DimDisplayWhenIdle =
        if (cfg.powerdevil.${optionsName}.displayAndBrightness.dimDisplay.enable != null) then
          cfg.powerdevil.${optionsName}.displayAndBrightness.dimDisplay.enable
        else if (cfg.powerdevil.${optionsName}.displayAndBrightness.dimDisplay.idleTimeout != null) then
          true
        else
          null;
      DimDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.displayAndBrightness.dimDisplay.idleTimeout;
      UseProfileSpecificDisplayBrightness=
        if (cfg.powerdevil.${optionsName}.displayAndBrightness.changeScreenBrightness.enable != null) then
          cfg.powerdevil.${optionsName}.displayAndBrightness.changeScreenBrightness.enable
        else if (cfg.powerdevil.${optionsName}.displayAndBrightness.changeScreenBrightness.percentage != null) then
          true
        else
          null;
      DisplayBrightness=cfg.powerdevil.${optionsName}.displayAndBrightness.changeScreenBrightness.percentage;
    };
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "AC" "powerButtonAction"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "AC" "autoSuspend"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "AC" "turnOffDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "autoSuspend"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "autoSuspend"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "autoSuspend"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "powerButtonAction"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "powerButtonAction"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "powerButtonAction"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "whenLaptopLidClosed"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "whenLaptopLidClosed"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "whenLaptopLidClosed"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "whenLaptopLidClosed"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "whenLaptopLidClosed"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "whenLaptopLidClosed"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "inhibitLidActionWhenExternalMonitorConnected"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "inhibitLidActionWhenExternalMonitorConnected"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "inhibitLidActionWhenExternalMonitorConnected"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "inhibitLidActionWhenExternalMonitorConnected"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "inhibitLidActionWhenExternalMonitorConnected"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "inhibitLidActionWhenExternalMonitorConnected"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "whenSleepingEnter"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "whenSleepingEnter"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "whenSleepingEnter"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "whenSleepingEnter"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "whenSleepingEnter"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "whenSleepingEnter"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "changeScreenBrightness"]
      ["programs" "plasma" "powerdevil" "AC" "displayAndBrightness" "changeScreenBrightness"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "changeScreenBrightness"]
      ["programs" "plasma" "powerdevil" "battery" "displayAndBrightness" "changeScreenBrightness"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "changeScreenBrightness"]
      ["programs" "plasma" "powerdevil" "lowBattery" "displayAndBrightness" "changeScreenBrightness"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "dimDisplay"]
      ["programs" "plasma" "powerdevil" "AC" "displayAndBrightness" "dimDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "dimDisplay"]
      ["programs" "plasma" "powerdevil" "battery" "displayAndBrightness" "dimDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "dimDisplay"]
      ["programs" "plasma" "powerdevil" "lowBattery" "displayAndBrightness" "dimDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "AC" "displayAndBrightness" "turnOffDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "battery" "displayAndBrightness" "turnOffDisplay"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "lowBattery" "displayAndBrightness" "turnOffDisplay"]
    )
  ];

  config.assertions =
    let
      createAssertions = type: [
        {
          assertion = (
            cfg.powerdevil.${type}.suspendSession.autoSuspend.action != autoSuspendActions.nothing
            || cfg.powerdevil.${type}.suspendSession.autoSuspend.idleTimeout == null
          );
          message = "Setting programs.plasma.powerdevil.${type}.suspendSession.autoSuspend.idleTimeout for autosuspend-action \"nothing\" is not supported.";
        }
        {
          assertion = (
            cfg.powerdevil.${type}.displayAndBrightness.turnOffDisplay.idleTimeout != -1
            || cfg.powerdevil.${type}.displayAndBrightness.turnOffDisplay.idleTimeoutWhenLocked == null
          );
          message = "Setting programs.plasma.powerdevil.${type}.displayAndBrightness.turnOffDisplay.idleTimeoutWhenLocked for idleTimeout \"never\" is not supported.";
        }
        {
          assertion = (
            cfg.powerdevil.${type}.displayAndBrightness.dimDisplay.enable != false
            || cfg.powerdevil.${type}.displayAndBrightness.dimDisplay.idleTimeout == null
          );
          message = "Cannot set programs.plasma.powerdevil.${type}.displayAndBrightness.dimDisplay.idleTimeout when programs.plasma.powerdevil.${type}.displayAndBrightness.dimDisplay.enable is disabled.";
        }
        {
          assertion = (
            cfg.powerdevil.${type}.displayAndBrightness.changeScreenBrightness.enable != false
            || cfg.powerdevil.${type}.displayAndBrightness.changeScreenBrightness.percentage == null
          );
          message = "Cannot set programs.plasma.powerdevil.${type}.displayAndBrightness.changeScreenBrightness.percentage when programs.plasma.powerdevil.${type}.displayAndBrightness.changeScreenBrightness.enable is disabled.";
        }
      ];
    in
    (createAssertions "AC") ++ (createAssertions "battery") ++ (createAssertions "lowBattery");

  options = {
    programs.plasma.powerdevil = {
      AC = (createPowerDevilOptions "AC");
      battery = (createPowerDevilOptions "battery");
      lowBattery = (createPowerDevilOptions "lowBattery");
      general = {
        pausePlayersOnSuspend = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          example = false;
          description = ''
            If enabled, pause media players when the system is suspended.
          '';
        };
      };
    };
  };

  config.programs.plasma.configFile = lib.mkIf cfg.enable {
    powerdevilrc = lib.filterAttrsRecursive (k: v: v != null) (
      (createPowerDevilConfig "AC" "AC")
      // (createPowerDevilConfig "Battery" "battery")
      // (createPowerDevilConfig "LowBattery" "lowBattery")
      // {
        General = {
          pausePlayersOnSuspend = cfg.powerdevil.general.pausePlayersOnSuspend;
        };
      }
    );
  };
}
