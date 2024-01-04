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
  let
    jsonStr = builtins.toJSON a;
    # Writing to file handles special characters better than passing it in as
    # an argument to the script.
    jsonFile = pkgs.writeText "data.json" jsonStr;
  in 
    ''
      ${writeConfigScript}/bin/write_config ${jsonFile}
    '';
in
{
  inherit writeConfig;
}
