# Low-level access to changing Plasma settings.
{ config, lib, pkgs, ... }:

let
  inherit (import ../lib/kwriteconfig.nix { inherit lib pkgs; })
    kWriteConfig;

  cfg = config.programs.plasma.files;

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
  options.programs.plasma.files = lib.mkOption {
    type = with lib.types; attrsOf (attrsOf (submodule settingType));
    default = { };
    description = ''
      An attribute set where the keys are file names (relative to
      XDG_CONFIG_HOME) and the values are attribute sets that
      represent configuration groups and settings inside those groups.
    '';
  };

  config = lib.mkIf (builtins.length (builtins.attrNames cfg) > 0) {
    home.activation.configure-plasma = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${script}
    '';
  };
}
