# Low-level access to changing Plasma settings.
{ config, lib, pkgs, ... }:

let
  inherit (import ../lib/writeconfig.nix { inherit lib pkgs config; }) writeConfig;
  inherit (import ../lib/types.nix { inherit lib; }) coercedSettingsType;

  # Helper function to prepend the appropriate path prefix (e.g. XDG_CONFIG_HOME) to file
  prependPath = prefix: attrset:
    lib.mapAttrs'
      (path: config: { name = "${prefix}/${path}"; value = config; })
      attrset;
  plasmaCfg = config.programs.plasma;
  cfg =
    (prependPath config.home.homeDirectory plasmaCfg.file) //
    (prependPath config.xdg.configHome plasmaCfg.configFile) //
    (prependPath config.xdg.dataHome plasmaCfg.dataFile);

  fileSettingsType = with lib.types; attrsOf (attrsOf (attrsOf coercedSettingsType));

  ##############################################################################
  # Generate a script that will use write_config.py to update all
  # settings.
  ocRemoveList = (map (f: "${config.xdg.configHome}/${f}") (lib.lists.subtractLists plasmaCfg.overrideConfigExclude plasmaCfg.overrideConfigFiles));
  script = pkgs.writeScript "plasma-config" (writeConfig cfg plasmaCfg.overrideConfig ocRemoveList);

  ##############################################################################
  # Generate a script that will remove all the current config files.
  defaultResetFiles = [
    "baloofilerc"
    "dolphinrc"
    "ffmpegthumbsrc"
    "kactivitymanagerdrc"
    "katerc"
    "kcminputrc"
    "kded5rc"
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
    "plasma-localerc"
    "plasmanotifyrc"
    "plasmarc"
    "plasmashellrc"
    "systemsettingsrc"
  ];
in
{
  options.programs.plasma = {
    file = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        HOME) and the values are attribute sets that represent
        configuration groups and settings inside those groups.
      '';
    };
    configFile = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        XDG_CONFIG_HOME) and the values are attribute sets that
        represent configuration groups and settings inside those groups.
      '';
    };
    dataFile = lib.mkOption {
      type = fileSettingsType;
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        XDG_DATA_HOME) and the values are attribute sets that
        represent configuration groups and settings inside those groups.
      '';
    };
    overrideConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Wether to discard changes made outside plasma-manager. If enabled all
        settings not specified explicitly in plasma-manager will be set to the
        default on next login. This will automatically delete a lot of
        kde-plasma config-files on each generation so be careful with this
        option.
      '';
    };
    overrideConfigFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultResetFiles;
      description = ''
        Config-files which should be deleted on each generation.
      '';
    };
    overrideConfigExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Config-files which explicitly should not be deleted on each generation.
      '';
    };
  };

  imports = [
    (lib.mkRenamedOptionModule [ "programs" "plasma" "files" ] [ "programs" "plasma" "configFile" ])
  ];

  config.home.activation = lib.mkIf plasmaCfg.enable {
    configure-plasma = (lib.hm.dag.entryAfter [ "writeBoundary" ]
      ''
        $DRY_RUN_CMD ${script} 
      '');
  };
}

