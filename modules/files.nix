# Low-level access to changing Plasma settings.
{ config, lib, pkgs, ... }:

let
  inherit (import ../lib/writeconfig.nix { inherit lib pkgs; })
    writeConfig;

  # Helper function to prepend the appropriate path prefix (e.g. XDG_CONFIG_HOME) to file
  prependPath = prefix: attrset:
    lib.attrsets.mapAttrs'
      (path: config: { name = "${prefix}/${path}"; value = config; })
      attrset;
  plasmaCfg = config.programs.plasma;
  cfg =
    (prependPath config.home.homeDirectory plasmaCfg.file) //
    (prependPath config.xdg.configHome plasmaCfg.configFile) //
    (prependPath config.xdg.dataHome plasmaCfg.dataFile);

  ##############################################################################
  # A module for storing settings.
  settingType = { name, ... }: {
    freeformType = with lib.types;
      attrsOf (nullOr (oneOf [ bool float int str ]));

    options = {
      configGroupNesting = lib.mkOption {
        type = lib.types.nonEmptyListOf lib.types.str;
        # We allow escaping periods using \\.
        default = (map
          (e: builtins.replaceStrings [ "\\u002E" ] [ "." ] e)
          (lib.splitString "."
            (builtins.replaceStrings [ "\\." ] [ "\\u002E" ] name)
          )
        );
        description = "Group name, and sub-group names.";
      };
    };
  };

  ##############################################################################
  # Generate a script that will use write_config.py to update all
  # settings.
  script = pkgs.writeScript "plasma-config" (writeConfig cfg);

  ##############################################################################
  # Generate a script that will remove all the current config files.
  defaultResetFiles = [
    "baloofilerc"
    "dolphinrc"
    "ffmpegthumbsrc"
    "kactivitymanagerdrc"
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

  # Creates command to remove file iff the file is present
  removeFileIfExistsCmd = f: "if [ -f ${f} ]; then rm ${f}; fi";
  # Here cfg should be sent in with programs.plasma when called.
  createResetScript = cfg: pkgs.writeScript "reset-plasma-config"
    (builtins.concatStringsSep
      "\n"
      ((map removeFileIfExistsCmd
        # The files in overrideConfigFiles are in XDG_CONFIG_HOME, so we need to
        # add this to the names to get the full path
        (map (f: "${config.xdg.configHome}/${f}") (lib.lists.subtractLists cfg.overrideConfigExclude cfg.overrideConfigFiles)))
      # Some of the startup-scripts may keep track of when they were last run,
      # in order to only run the scripts once for each home-manager generation.
      # However when we use overrideConfig we need to run these scripts after
      # every activation (i.e. after applying a new home-manager generation or
      # after a fresh boot) as the scripts typically write some config-files
      # which will need to be written once again after the old configs are
      # deleted on each activation.
      ++ [ "for file in ${config.xdg.dataHome}/plasma-manager/last_run_*; do ${removeFileIfExistsCmd "$file"}; done" ]));
in
{
  options.programs.plasma = {
    file = lib.mkOption {
      type = with lib.types; attrsOf (attrsOf (submodule settingType));
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        HOME) and the values are attribute sets that represent
        configuration groups and settings inside those groups.
      '';
    };
    configFile = lib.mkOption {
      type = with lib.types; attrsOf (attrsOf (submodule settingType));
      default = { };
      description = ''
        An attribute set where the keys are file names (relative to
        XDG_CONFIG_HOME) and the values are attribute sets that
        represent configuration groups and settings inside those groups.
      '';
    };
    dataFile = lib.mkOption {
      type = with lib.types; attrsOf (attrsOf (submodule settingType));
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

  config = lib.mkIf plasmaCfg.enable {
    home.activation.configure-plasma = (lib.hm.dag.entryAfter [ "writeBoundary" ]
      ''
        $DRY_RUN_CMD ${if plasmaCfg.overrideConfig then (createResetScript plasmaCfg) else ""}
        $DRY_RUN_CMD ${script}
      '');
  };
}
