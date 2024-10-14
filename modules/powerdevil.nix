{ config, lib, ... }:
let
  cfg = config.programs.plasma;

  # ============================
  # === options declarations ===
  # ============================

  afterAPeriodOfInactivityActions = {
    doNothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
  };

  # Values can be found at:
  # https://github.com/KDE/powerdevil/blob/master/daemon/powerdevilenums.h
  whenPowerButtonPressedActions = {
    doNothing = 0;
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
    shutDown = 8;
    lockScreen = 32;
    turnOffScreen = 64;
  };

  whenSleepingEnterActions = {
    standby = 1;
    hybridSleep = 2;
    standbyThenHibernate = 3;
  };

  switchToPowerProfileActions = {
    leaveUnchanged = "leave-unchanged";
    powerSave = "power-saver";
    balanced = "balanced";
    performance = "performance";
  };

  atCriticalLevelActions = {
    doNothing = 0;
    sleep = 1;
    hibernate = 2;
    shutDown = 8;
  };

  # ancillary function
  capitalize = string:
    with lib.strings;
    concatImapStrings
      (pos: char:
        if (pos == 1) then
          toUpper char
        else
          char)
      (stringToCharacters string);

  # Since AC and battery allows the same options we create a function here which
  # can generate the options by just specifying the type (i.e. "AC" or
  # "battery").
  generateOptionsForProfile = profile: {
    suspendSession = {
      afterAPeriodOfInactivity = {
        action = lib.mkOption {
          type = with lib.types;
            nullOr (enum (builtins.attrNames afterAPeriodOfInactivityActions));
          default = null;
          example = "doNothing";
          description = "The action, when on ${profile}, to perform after a certain period of inactivity.";
          apply = action:
            if (action == null) then
              null
            else
              afterAPeriodOfInactivityActions."${action}";
        };

        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr (ints.between 60 604800);
          default = null;
          example = 600;
          description = "The duration (in seconds), when on ${profile}, the computer must be idle until the auto-suspend action is executed.";
        };
      };

      whenPowerButtonPressed = lib.mkOption {
        type = with lib.types;
          nullOr (enum (builtins.attrNames whenPowerButtonPressedActions));
        default = null;
        example = "doNothing";
        description = "The action, when on ${profile}, to perform when the power button is pressed.";
        apply = action:
          if (action == null) then
            null
          else
            whenPowerButtonPressedActions."${action}";
      };

      whenLaptopLidClosed = lib.mkOption {
        type = with lib.types;
          nullOr (enum (builtins.attrNames whenLaptopLidClosedActions));
        default = null;
        example = "shutDown";
        description = "The action, when on ${profile}, to perform when the laptop lid is closed.";
        apply = action:
          if (action == null) then
            null
          else
            whenLaptopLidClosedActions."${action}";
      };

      evenWhenAnExternalMonitorIsConnected = lib.mkOption {
        type = with lib.types;
          nullOr bool;
        default = null;
        example = false;
        description = "If enabled, when on ${profile}, the lid action will be executed even when an external monitor is connected.";
      };

      whenSleepingEnter = lib.mkOption {
        type = with lib.types;
          nullOr (enum (builtins.attrNames whenSleepingEnterActions));
        default = null;
        example = "standbyThenHibernate";
        description = "The state, when on ${profile}, to enter when sleeping.";
        apply = action:
          if (action == null) then
            null
          else
            whenSleepingEnterActions."${action}";
      };
    };

    displayAndBrightness = {
      changeScreenBrightness = {
        enable = lib.mkOption {
          type = with lib.types;
            nullOr bool;
          default = null;
          example = true;
          description = "Enable or disable, when on ${profile}, changing the screen brightness.";
        };

        percentage = lib.mkOption {
          type = with lib.types;
            nullOr (ints.between 1 100);
          default = null;
          example = 70;
          description = "The screen brightness percentage when on ${profile}.";
        };
      };

      dimAutomatically = {
        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr (either
              (enum ["never"])
              (ints.between 10 604800));
          default = null;
          example = 300;
          description = "The duration (in seconds), when on ${profile}, the computer must be idle until the display starts dimming.";
          apply = timeout:
            if (timeout == null) then
              null
            else if (timeout == "never") then
              -1
            else
              timeout;
        };
      };

      turnOffScreen = {
        idleTimeout = lib.mkOption {
          type = with lib.types;
            nullOr (either
              (enum [ "never" ])
              (ints.between 30 604800));
          default = null;
          example = 300;
          description = "The duration (in seconds), when on ${profile}, the computer must be idle (when unlocked) until the display turns off.";
          apply = timeout:
            if (timeout == null) then
              null
            else if (timeout == "never") then
              -1
            else
              timeout;
        };

        idleTimeoutWhenLocked = lib.mkOption {
          type = with lib.types;
            nullOr (either
              (enum ["whenLockedAndUnlocked" "immediately"])
              (ints.between 10 604800));
          default = null;
          example = 60;
          description = "The duration (in seconds), when on ${profile}, the computer must be idle (when locked) until the display turns off.";
          apply = timeout:
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

      changeKeyboardBrightness = {
        enable = lib.mkOption {
          type = with lib.types;
            nullOr bool;
          default = null;
          example = true;
          description = "Enable or disable, when on ${profile}, changing the keyboard brightness.";
        };

        percentage = lib.mkOption {
          type = with lib.types;
            nullOr (ints.between 0 100);
          default = null;
          example = 70;
          description = "The keyboard brightness percentage when on ${profile}.";
        };
      };
    };

    otherSettings = {
      switchToPowerProfile = lib.mkOption {
        type = with lib.types;
          nullOr (enum (builtins.attrNames switchToPowerProfileActions));
        default = null;
        example = "performance";
        description = "The power profile, when on ${profile}, adopted by the computer.";
        apply = profile:
          if (profile == null || profile == "leaveUnchanged") then
            null
          else
            switchToPowerProfileActions."${profile}";
      };

      runCustomScripts = {
        "whenEnteringOn${capitalize(profile)}PowerState" = lib.mkOption {
          type = with lib.types;
            nullOr str;
          default = null;
          example = "echo 'hello, world'";
          description = "A script or the path for a script/program to be run when entering ${profile}.";
        };

        "whenExitingOn${capitalize(profile)}PowerState" = lib.mkOption {
          type = with lib.types;
            nullOr str;
          default = null;
          example = "echo 'farewwll, world'";
          description = "A script or the path for a script/program to be run when exiting ${profile}.";
        };

        afterAPeriodOfInactivity = {
          script = lib.mkOption {
            type = with lib.types;
              nullOr str;
            default = null;
            example = "echo 'are you there, world'";
            description = "A script or the path for a script/program to be run after a period of inactivity when on ${profile}.";
          };

          idleTimeout = lib.mkOption {
            type = with lib.types;
              nullOr (ints.between 10 604800);
            default = null;
            example = 600;
            description = "The duration (in seconds), when on ${profile}, the computer must be idle until the script is run.";
          };
        };
      };
    };
  };

  generalOptions = {
    batteryLevels = {
      lowLevel = lib.mkOption {
        type = with lib.types;
          nullOr (ints.between 0 100);
        default = null;
        example = "10";
        description = "The battery charge will be considered low when it drops to this level. Settings for low battery will be used instead of regular battery settings.";
      };

      criticalLevel = lib.mkOption {
        type = with lib.types;
          nullOr (ints.between 0 100);
        default = null;
        example = "5";
        description = "The battery charge will be considered critical when it drops to this level. After a brief warning, the system will automaticelly suspend or shutdown, according to the configured critical battery level action.";
      };

      atCriticalLevel = lib.mkOption {
        type = with lib.types;
          nullOr (enum (builtins.attrNames atCriticalLevelActions));
        default = null;
        example = "hibernate";
        description = "The action to perform when the battery reaches critical level.";
        apply = action:
          if (action == null) then
            null
          else
            atCriticalLevelActions."${action}";
      };

      lowLevelForPeripheralDevice = lib.mkOption {
        type = with lib.types;
          nullOr (ints.between 0 100);
        default = null;
        example = "10";
        description = "The battery charge for peripheral devices will be considered low when it reaches this level.";
      };
    };

    otherSettings = {
      pauseMediaPlayersWhenSuspending = lib.mkOption {
        type = with lib.types;
          nullOr bool;
        default = null;
        example = false;
        description = "If enabled, pause media players when the system is suspended.";
      };
    };
  };


  # ==================================
  # === configuration declarations ===
  # ==================================

  # By the same logic as generateOptionsForProfile, we can generate the
  # configuration. cfgSectName is here the name of the section in powerdevilrc,
  # while profile is the name of the "namespace" where we should draw the
  # options from (i.e. powerdevil.AC or powerdevil.battery).
  generateConfigForProfile = cfgSectName: profile: {
    "${cfgSectName}/SuspendAndShutdown" = {
      AutoSuspendAction = cfg.powerdevil.${profile}.suspendSession.afterAPeriodOfInactivity.action;
      AutoSuspendIdleTimeoutSec = cfg.powerdevil.${profile}.suspendSession.afterAPeriodOfInactivity.idleTimeout;
      PowerButtonAction = cfg.powerdevil.${profile}.suspendSession.whenPowerButtonPressed;
      LidAction = cfg.powerdevil.${profile}.suspendSession.whenLaptopLidClosed;
      InhibitLidActionWhenExternalMonitorPresent = ! cfg.powerdevil.${profile}.suspendSession.evenWhenAnExternalMonitorIsConnected;
      SleepMode = cfg.powerdevil.${profile}.suspendSession.whenSleepingEnter;
    };

    "${cfgSectName}/Display" = {
      UseProfileSpecificDisplayBrightness=
        if (cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.enable != null) then
          cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.enable
        else if (cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.percentage != null) then
          true
        else
          null;
      DisplayBrightness=cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.percentage;
      DimDisplayIdleTimeoutSec = cfg.powerdevil.${profile}.displayAndBrightness.dimAutomatically.idleTimeout;
      TurnOffDisplayIdleTimeoutSec = cfg.powerdevil.${profile}.displayAndBrightness.turnOffScreen.idleTimeout;
      TurnOffDisplayIdleTimeoutWhenLockedSec =
        cfg.powerdevil.${profile}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked;
    };

    "${cfgSectName}/Keyboard" = {
      UseProfileSpecificKeyboardBrightness=
        if (cfg.powerdevil.${profile}.displayAndBrightness.changeKeyboardBrightness.enable != null) then
          cfg.powerdevil.${profile}.displayAndBrightness.changeKeyboardBrightness.enable
        else if (cfg.powerdevil.${profile}.displayAndBrightness.changeKeyboardBrightness.percentage != null) then
          true
        else
          null;
      KeyboardBrightness=cfg.powerdevil.${profile}.displayAndBrightness.changeKeyboardBrightness.percentage;
    };

    "${cfgSectName}/Performance" = {
      PowerProfile=cfg.powerdevil.${profile}.otherSettings.switchToPowerProfile;
    };

    "${cfgSectName}/RunScript" = {
      ProfileLoadCommand = cfg.powerdevil.${profile}.otherSettings.runCustomScripts."whenEnteringOn${capitalize(profile)}PowerState";
      ProfileUnloadCommand=cfg.powerdevil.${profile}.otherSettings.runCustomScripts."whenExitingOn${capitalize(profile)}PowerState";
      IdleTimeoutCommand=cfg.powerdevil.${profile}.otherSettings.runCustomScripts.afterAPeriodOfInactivity.script;
      RunScriptIdleTimeoutSec=cfg.powerdevil.${profile}.otherSettings.runCustomScripts.afterAPeriodOfInactivity.idleTimeout;
    };
  };

  generalConfig = {
    BatteryManagement = {
      BatteryLowLevel = cfg.powerdevil.batteryLevels.lowLevel;
      BatteryCriticalLevel = cfg.powerdevil.batteryLevels.criticalLevel;
      BatteryCriticalAction = cfg.powerdevil.batteryLevels.atCriticalLevel;
      PeripheralBatteryLowLevel = cfg.powerdevil.batteryLevels.lowLevelForPeripheralDevice;
    };
    General = {
      pausePlayersOnSuspend = cfg.powerdevil.otherSettings.pauseMediaPlayersWhenSuspending;
    };
  };


  # =============================================
  # === modified options modules declarations ===
  # =============================================

  generateModifiedOptionsModules = profile:
    [
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "autoSuspend"]
        ["programs" "plasma" "powerdevil" "${profile}" "suspendSession" "afterAPeriodOfInactivity"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "powerButtonAction"]
        ["programs" "plasma" "powerdevil" "${profile}" "suspendSession" "whenPowerButtonPressed"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "whenLaptopLidClosed"]
        ["programs" "plasma" "powerdevil" "${profile}" "suspendSession" "whenLaptopLidClosed"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "inhibitLidActionWhenExternalMonitorConnected"]
        ["programs" "plasma" "powerdevil" "${profile}" "suspendSession" "evenWhenAnExternalMonitorIsConnected"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "whenSleepingEnter"]
        ["programs" "plasma" "powerdevil" "${profile}" "suspendSession" "whenSleepingEnter"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "changeScreenBrightness"]
        ["programs" "plasma" "powerdevil" "${profile}" "displayAndBrightness" "changeScreenBrightness"]
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "dimDisplay"]
        ["programs" "plasma" "powerdevil" "${profile}" "displayAndBrightness" "dimAutomatically"]
      )
      (lib.mkRemovedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "displayAndBrightness" "dimAutomatically" "enable"]
        "The programs.plasma.powerdevil.${profile}.displayAndbrightness.dimAutomatically.enable option was removed. If you wish to disable the screen to dim automatically, set the programs.plasma.powerdevil.${profile}.displayAndbrightness.dimAutomatically.idleTimeout to \"never\"."
      )
      (lib.mkRenamedOptionModule
        ["programs" "plasma" "powerdevil" "${profile}" "turnOffDisplay"]
        ["programs" "plasma" "powerdevil" "${profile}" "displayAndBrightness" "turnOffScreen"]
      )
    ];

  generalModifiedOptionsModules = [
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
      ["programs" "plasma" "powerdevil" "general" "pausePlayersOnSuspend"]
      ["programs" "plasma" "powerdevil" "otherSettings" "pauseMediaPlayersWhenSuspending"]
    )
  ];


  # ===============================
  # === assertions declarations ===
  # ===============================

  generateAssertionsForProfile = profile: [
    {
      assertion = (
        cfg.powerdevil.${profile}.suspendSession.afterAPeriodOfInactivity.action != afterAPeriodOfInactivityActions.doNothing
        || cfg.powerdevil.${profile}.suspendSession.afterAPeriodOfInactivity.idleTimeout == null
      );
      message = "Setting programs.plasma.powerdevil.${profile}.suspendSession.afterAPeriodOfInactivity.idleTimeout for autosuspend-action \"doNothing\" is not supported.";
    }
    {
      assertion = (
        cfg.powerdevil.${profile}.displayAndBrightness.turnOffScreen.idleTimeout != -1
        || cfg.powerdevil.${profile}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked == null
      );
      message = "Setting programs.plasma.powerdevil.${profile}.displayAndBrightness.turnOffScreen.idleTimeoutWhenLocked for idleTimeout \"never\" is not supported.";
    }
    {
      assertion = (
        cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.enable != false
        || cfg.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.percentage == null
      );
      message = "Cannot set programs.plasma.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.percentage when programs.plasma.powerdevil.${profile}.displayAndBrightness.changeScreenBrightness.enable is disabled.";
    }
  ];

  generalAssertions = [
    {
      assertion = (
        cfg.powerdevil.batteryLevels.lowLevel == null
        || cfg.powerdevil.batteryLevels.criticalLevel == null
        || cfg.powerdevil.batteryLevels.lowLevel > cfg.powerdevil.batteryLevels.criticalLevel
      );
      message = "programs.plasma.powerdevil.batteryLevels.criticalLevel cannot be greater than programs.plasma.powerdevil.batteryLevels.lowLevel.";
    }
  ];

in
{
  imports =
    (generateModifiedOptionsModules "AC")
    ++ (generateModifiedOptionsModules "battery")
    ++ (generateModifiedOptionsModules "lowBattery")
    ++ generalModifiedOptionsModules;

  config.assertions =
    (generateAssertionsForProfile "AC")
    ++ (generateAssertionsForProfile "battery")
    ++ (generateAssertionsForProfile "lowBattery")
    ++ generalAssertions;

  options = {
    programs.plasma.powerdevil = {
      AC = (generateOptionsForProfile "AC");
      battery = (generateOptionsForProfile "battery");
      lowBattery = (generateOptionsForProfile "lowBattery");
    }
    // generalOptions;
  };

  config.programs.plasma.configFile = lib.mkIf cfg.enable {
    powerdevilrc = lib.filterAttrsRecursive (k: v: v != null) (
      (generateConfigForProfile "AC" "AC")
      // (generateConfigForProfile "Battery" "battery")
      // (generateConfigForProfile "LowBattery" "lowBattery")
      // generalConfig
    );
  };
}
