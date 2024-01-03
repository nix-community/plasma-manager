{ pkgs, lib }:

let
  writeConfigScript = pkgs.writeShellApplication {
    name = "write_config";
    runtimeInputs = with pkgs; [ python3 ];
    text = ''python ${../script/write_config.py} "$@"'';
  };

  ##############################################################################
  # Generate a command to run the config-writer script by first sending in the
  # attribute-set as json. Here a is the attribute-set.
  #
  # Type: AttrSet -> string
  writeConfig = a:
    ''
      ${writeConfigScript}/bin/write_config '${builtins.toJSON a}'
    '';
in
{
  inherit writeConfig;
}
