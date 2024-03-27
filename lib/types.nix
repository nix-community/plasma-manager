{ lib, ... }:
let
  ##############################################################################
  # Types for storing settings.
  basicSettingsType = (with lib.types;
    nullOr (oneOf [ bool float int str ]));
  advancedSettingsType = (with lib.types; submodule {
    options = {
      value = lib.mkOption {
        type = basicSettingsType;
        default = null;
        description = "The value for some key.";
      };
      immutable = lib.mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to make the key immutable. This corresponds to adding [$i] to
          the end of the key.
        '';
      };
      shellExpand = lib.mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to mark the key for shell expansion. This corresponds to
          adding [$e] to the end of the key.
        '';
      };
    };
  });
in
{
  inherit basicSettingsType;
  inherit advancedSettingsType;
}
