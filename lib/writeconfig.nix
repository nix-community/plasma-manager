{ pkgs, config, ... }:

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
  writeConfig =
    json: overrideConfig: resetFilesList:
    let
      jsonStr = builtins.toJSON json;
      # Writing to file handles special characters better than passing it in as
      # an argument to the script.
      jsonFile = pkgs.writeText "data.json" jsonStr;
      resetFilesStr = builtins.toString (
        if overrideConfig then
          resetFilesList ++ [ "${config.xdg.dataHome}/plasma-manager/last_run_*" ]
        else
          resetFilesList
      );
      immutableByDefault = (builtins.toString config.programs.plasma.immutableByDefault);
    in
    ''
      ${writeConfigScript}/bin/write_config ${jsonFile} "${resetFilesStr}" "${immutableByDefault}"
    '';
in
{
  inherit writeConfig;
}
