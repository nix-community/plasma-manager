# Low-level access to changing Plasma settings.
{ config, lib, pkgs, ... }:

let
  inherit (import ../lib/kwriteconfig.nix { inherit lib pkgs; })
    kWriteConfig;

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
        default = (lib.splitString "." name);
        description = "Group name, and sub-group names.";
      };
    };
  };

  ##############################################################################
  # Remove reserved options from a settings attribute set.
  settingsToConfig = settings:
    lib.filterAttrs
      (k: v: !(builtins.elem k [ "configGroupNesting" ]))
      settings;

  ##############################################################################
  # Generate a script that will use kwriteconfig to update all
  # settings.
  script = pkgs.writeScript "plasma-config"
    (lib.concatStrings
      (lib.mapAttrsToList
        (file: settings: lib.concatMapStringsSep "\n"
          (set: kWriteConfig file set.configGroupNesting (settingsToConfig set))
          (builtins.attrValues settings))
        cfg));
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
  };

  imports = [
    (lib.mkRenamedOptionModule [ "programs" "plasma" "files" ] [ "programs" "plasma" "configFile" ])
  ];

  config = lib.mkIf (builtins.length (builtins.attrNames cfg) > 0) {
    home.activation.configure-plasma = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${script}
    '';
  };
}
