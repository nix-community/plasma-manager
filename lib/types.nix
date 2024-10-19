{ lib, config, ... }:
let
  ##############################################################################
  # Types for storing settings.
  basicSettingsType = (
    with lib.types;
    nullOr (oneOf [
      bool
      float
      int
      str
    ])
  );
  advancedSettingsType = (
    with lib.types;
    submodule {
      options = {
        value = lib.mkOption {
          type = basicSettingsType;
          default = null;
          description = "The value for some key.";
        };
        immutable = lib.mkOption {
          type = bool;
          default = config.programs.plasma.immutableByDefault;
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
        persistent = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            When overrideConfig is enabled and the key is persistent,
            plasma-manager will leave it unchanged after activation.
          '';
        };
        escapeValue = lib.mkOption {
          type = bool;
          default = true;
          description = ''
            Whether to escape the value according to kde's escape-format. See:
            https://invent.kde.org/frameworks/kconfig/-/blob/v6.7.0/src/core/kconfigini.cpp?ref_type=tags#L880-945
            for info about this format.
          '';
        };
      };
    }
  );
  coercedSettingsType =
    with lib.types;
    coercedTo basicSettingsType (value: { inherit value; }) advancedSettingsType;
in
{
  inherit basicSettingsType;
  inherit advancedSettingsType;
  inherit coercedSettingsType;
}
