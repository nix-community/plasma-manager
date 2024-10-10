{ config, lib, ... }:
let
  cfg = config.programs.plasma;

  afterAPeriodOfInactivityActions = {
    nothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
  };

  # Values can be found at:
  # https://github.com/KDE/powerdevil/blob/master/daemon/powerdevilenums.h
  whenPowerButtonPressedActions = {
    nothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
    lockScreen = 32;
    showLogoutScreen = 16;
    turnOffScreen = 64;
  };

  whenLaptopLidClosedActions = {
    doNothing = 0;
    sleep = 1;
    hibernate = 2;
    shutdown = 8;
    lockScreen = 32;
    turnOffScreen = 64;
  };

  whenSleepingEnterActions = {
    standby = 1;
    hybridSleep = 2;
    standbyThenHibernate = 3;
  };

  # Since AC and battery allows the same options we create a function here which
  # can generate the options by just specifying the type (i.e. "AC" or
  # "battery").
  createPowerDevilOptions = type: {
    suspendSession = {
      afterAPeriodOfInactivity = {
        action = lib.mkOption {
          type = with lib.types;
            nullOr (
              enum (
                builtins.attrNames afterAPeriodOfInactivityActions
              )
            );
          default = null;
          example = "nothing";
          description = ''
            The action, when on ${type}, to perform after a certain period of inactivity.
          '';
          apply = action:
            if (action == null)
            then null
            else afterAPeriodOfInactivityActions."${action}";
        };

        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr (
              ints.between 60 600000
            );
          default = null;
          example = 600;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            until the auto-suspend action is executed.
          '';
        };
      };

      whenPowerButtonPressed = lib.mkOption {
        type = with lib.types;
          nullOr (
            enum (
              builtins.attrNames whenPowerButtonPressedActions
            )
          );
        default = null;
        example = "nothing";
        description = ''
          The action, when on ${type}, to perform when the power button is pressed.
        '';
        apply = action:
          if (action == null)
          then null
          else whenPowerButtonPressedActions."${action}";
      };

      whenLaptopLidClosed = lib.mkOption {
        type = with lib.types;
          nullOr (
            enum (
              builtins.attrNames whenLaptopLidClosedActions
            )
          );
        default = null;
        example = "shutdown";
        description = ''
          The action, when on ${type}, to perform when the laptop lid is closed.
        '';
        apply = action:
          if (action == null)
          then null
          else whenLaptopLidClosedActions."${action}";
      };

      evenWhenAnExternalMonitorIsConnected = lib.mkOption {
        type = with lib.types;
          nullOr (
            bool
          );
        default = null;
        example = false;
        description = ''
          If enabled, the lid action will be executed even when an external monitor is connected.
        '';
      };

      whenSleepingEnter = lib.mkOption {
        type = with lib.types;
          nullOr (
            enum (
              builtins.attrNames whenSleepingEnterActions
            )
          );
        default = null;
        example = "standbyThenHibernate";
        description = ''
          The state, when on ${type}, to enter when sleeping.
        '';
        apply = action:
          if (action == null)
          then null
          else whenSleepingEnterActions."${action}";
      };
    };

    displayAndBrightness = {
      changeScreenBrightness = {
        enable = lib.mkOption {
          type = with lib.types;
            nullOr (
              bool
            );
          default = null;
          example = true;
          description = ''
            Enable or disable screen brightness changing.
          '';
        };

        percentage = lib.mkOption {
          type = with lib.types;
            nullOr (
              ints.between 0 100
            );
          default = null;
          example = 70;
          description = ''
            The screen brightness percentage when on ${type}.
          '';
        };
      };

      dimAutomatically = {
        enable = lib.mkOption {
          type = with lib.types;
            nullOr
            bool;
          default = null;
          example = false;
          description = ''
            Enable or disable screen dimming.
          '';
        };

        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr
            (ints.between 20 600000);
          default = null;
          example = 300;
          description = ''
            The duration (in seconds), when on ${type}, the computer must be idle
            until the display starts dimming.
          '';
        };
      };

      turnOffScreen = {
        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr (either (enum [ "never" ]) (ints.between 30 600000));
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
      PowerButtonAction = cfg.powerdevil.${optionsName}.suspendSession.whenPowerButtonPressed;
      AutoSuspendAction = cfg.powerdevil.${optionsName}.suspendSession.afterAPeriodOfInactivity.action;
      AutoSuspendIdleTimeoutSec = cfg.powerdevil.${optionsName}.suspendSession.afterAPeriodOfInactivity.idleTimeout;
      SleepMode = cfg.powerdevil.${optionsName}.suspendSession.whenSleepingEnter;
      LidAction = cfg.powerdevil.${optionsName}.suspendSession.whenLaptopLidClosed;
      InhibitLidActionWhenExternalMonitorPresent = ! cfg.powerdevil.${optionsName}.suspendSession.evenWhenAnExternalMonitorIsConnected;
    };
    "${cfgSectName}/Display" = {
      TurnOffDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.displayAndBrightness.turnOffScreen.idleTimeout;
      TurnOffDisplayIdleTimeoutWhenLockedSec =
        cfg.powerdevil.${optionsName}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked;
      DimDisplayWhenIdle =
        if (cfg.powerdevil.${optionsName}.displayAndBrightness.dimAutomatically.enable != null) then
          cfg.powerdevil.${optionsName}.displayAndBrightness.dimAutomatically.enable
        else if (cfg.powerdevil.${optionsName}.displayAndBrightness.dimAutomatically.idleTimeout != null) then
          true
        else
          null;
      DimDisplayIdleTimeoutSec = cfg.powerdevil.${optionsName}.displayAndBrightness.dimAutomatically.idleTimeout;
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
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "afterAPeriodOfInactivity"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "afterAPeriodOfInactivity"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "autoSuspend"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "afterAPeriodOfInactivity"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "whenPowerButtonPressed"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "whenPowerButtonPressed"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "powerButtonAction"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "whenPowerButtonPressed"]
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
      ["programs" "plasma" "powerdevil" "AC" "suspendSession" "evenWhenAnExternalMonitorIsConnected"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "inhibitLidActionWhenExternalMonitorConnected"]
      ["programs" "plasma" "powerdevil" "battery" "suspendSession" "evenWhenAnExternalMonitorIsConnected"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "inhibitLidActionWhenExternalMonitorConnected"]
      ["programs" "plasma" "powerdevil" "lowBattery" "suspendSession" "evenWhenAnExternalMonitorIsConnected"]
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
      ["programs" "plasma" "powerdevil" "AC" "displayAndBrightness" "dimAutomatically"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "dimDisplay"]
      ["programs" "plasma" "powerdevil" "battery" "displayAndBrightness" "dimAutomatically"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "dimDisplay"]
      ["programs" "plasma" "powerdevil" "lowBattery" "displayAndBrightness" "dimAutomatically"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "AC" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "AC" "displayAndBrightness" "turnOffScreen"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "battery" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "battery" "displayAndBrightness" "turnOffScreen"]
    )
    (lib.mkRenamedOptionModule
      ["programs" "plasma" "powerdevil" "lowBattery" "turnOffDisplay"]
      ["programs" "plasma" "powerdevil" "lowBattery" "displayAndBrightness" "turnOffScreen"]
    )
  ];

  config.assertions =
    let
      createAssertions = type: [
        {
          assertion = (
            cfg.powerdevil.${type}.suspendSession.afterAPeriodOfInactivity.action != afterAPeriodOfInactivityActions.nothing
            || cfg.powerdevil.${type}.suspendSession.afterAPeriodOfInactivity.idleTimeout == null
          );
          message = "Setting programs.plasma.powerdevil.${type}.suspendSession.afterAPeriodOfInactivity.idleTimeout for autosuspend-action \"nothing\" is not supported.";
        }
        {
          assertion = (
            cfg.powerdevil.${type}.displayAndBrightness.turnOffScreen.idleTimeout != -1
            || cfg.powerdevil.${type}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked == null
          );
          message = "Setting programs.plasma.powerdevil.${type}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked for idleTimeout \"never\" is not supported.";
        }
        {
          assertion = (
            cfg.powerdevil.${type}.displayAndBrightness.dimAutomatically.enable != false
            || cfg.powerdevil.${type}.displayAndBrightness.dimAutomatically.idleTimeout == null
          );
          message = "Cannot set programs.plasma.powerdevil.${type}.displayAndBrightness.dimAutomatically.idleTimeout when programs.plasma.powerdevil.${type}.displayAndBrightness.dimAutomatically.enable is disabled.";
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
