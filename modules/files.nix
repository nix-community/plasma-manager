# Low-level access to changing Plasma settings.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (import ../lib/writeconfig.nix { inherit lib pkgs config; }) writeConfig;
  inherit
    (import ../lib/types.nix {
      inherit lib;
      inherit config;
    })
    coercedSettingsType
    ;

  # Helper function to prepend the appropriate path prefix (e.g. XDG_CONFIG_HOME) to file
  prependPath =
    prefix: attrset:
    lib.mapAttrs' (path: config: {
      name = "${prefix}/${path}";
      value = config;
    }) attrset;
  plasmaCfg = config.programs.plasma;
  cfg =
    (prependPath config.home.homeDirectory plasmaCfg.file)
    // (prependPath config.xdg.configHome plasmaCfg.configFile)
    // (prependPath config.xdg.dataHome plasmaCfg.dataFile);

  fileSettingsType = with lib.types; attrsOf (attrsOf (attrsOf coercedSettingsType));

  ##############################################################################
  # Generate a script that will use write_config.py to update all
  # settings.
  resetFilesList = (
    map (f: "${config.xdg.configHome}/${f}") (
      lib.lists.subtractLists plasmaCfg.resetFilesExclude plasmaCfg.resetFiles
    )
  );
  script = pkgs.writeScript "plasma-config" (writeConfig cfg plasmaCfg.overrideConfig resetFilesList);

  ##############################################################################
  # Generate a script that will remove all the current config files.
  defaultResetFiles = (
    if plasmaCfg.overrideConfig then
      [
        "auroraerc"
        "baloofilerc"
        "dolphinrc"
        "ffmpegthumbsrc"
        "kactivitymanagerdrc"
        "katerc"
        "kcminputrc"
        "KDE/Sonnet.conf"
        "kde.org/ghostwriter.conf"
        "kded5rc"
        "kded6rc"
        "kdeglobals"
        "kgammarc"
        "kglobalshortcutsrc"
        "khotkeysrc"
        "kiorc"
        "klaunchrc"
        "klipperrc"
        "kmixrc"
        "krunnerrc"
        "kscreenlockerrc"
        "kservicemenurc"
        "ksmserverrc"
        "ksplashrc"
        "kwalletrc"
        "kwin_rules_dialogrc"
        "kwinrc"
        "kwinrulesrc"
        "kxkbrc"
        "plasma_calendar_alternatecalendar"
        "plasma_calendar_astronomicalevents"
        "plasma_calendar_holiday_regions"
        "plasma-localerc"
        "plasmanotifyrc"
        "plasmarc"
        "plasmashellrc"
        "powerdevilrc"
        "systemsettingsrc"
      ]
    else
      lib.optional (builtins.length plasmaCfg.window-rules > 0) "kwinrulesrc"
  );
in
{
  options.programs.plasma = {
    file = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        `$HOME`) and the values are attribute sets that represent
        configuration groups and settings inside those groups.
      '';
    };
    configFile = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        `$XDG_CONFIG_HOME`) and the values are attribute sets that
        represent configuration groups and settings inside those groups.
      '';
    };
    dataFile = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        `$XDG_DATA_HOME`) and the values are attribute sets that
        represent configuration groups and settings inside those groups.
      '';
    };
    overrideConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Wether to discard changes made outside `plasma-manager`. If enabled, all
        settings not specified explicitly in `plasma-manager` will be set to the
        default on next login. This will automatically delete a lot of
        KDE Plasma configuration files on each generation, so do be careful with this
        option.
      '';
    };
    resetFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultResetFiles;
      description = ''
        Configuration files which should be explicitly deleted on each generation.
      '';
    };
    resetFilesExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Configuration files which explicitly should not be deleted on each generation, if `overrideConfig` is enabled.
      '';
    };
    immutableByDefault = lib.mkEnableOption "Make keys written by plasma-manager immutable by default.";
  };

  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "files"
      ]
      [
        "programs"
        "plasma"
        "configFile"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "overrideConfigFiles"
      ]
      [
        "programs"
        "plasma"
        "resetFiles"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "plasma"
        "overrideConfigExclude"
      ]
      [
        "programs"
        "plasma"
        "resetFilesExclude"
      ]
    )
  ];

  config.home.activation = lib.mkIf plasmaCfg.enable {
    configure-plasma = (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${script}
      ''
    );
  };
}
