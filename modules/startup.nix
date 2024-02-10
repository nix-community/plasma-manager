# Allows to run commands/scripts at startup (this is used by some of the other
# modules, which may need to do this, but can also be used on its own)
{ config, lib, ... }:
let
  cfg = config.programs.plasma;
  topScriptName = "run_all.sh";

  startupScriptType = lib.types.submodule {
    options = {
      text = lib.mkOption {
        type = lib.types.str;
        description = "The content of the startup-script.";
      };
      priority = lib.mkOption {
        type = lib.types.int;
        description = "The priority for the execution of the script. Lower priority means earlier execution.";
        default = 0;
      };
    };
  };
in
{
  options.programs.plasma.startup = {
    autoStartScript = lib.mkOption {
      type = lib.types.attrsOf startupScriptType;
      default = { };
      description = "Commands/scripts to be run at startup.";
    };
    dataFile = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Datafiles, typically for use from autstart scripts.";
    };
    scriptsDir = lib.mkOption {
      type = lib.types.str;
      default = "scripts";
      description = "The name of the subdirectory where the scripts should be.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "The name of the subdirectory where the datafiles should be.";
    };
  };

  config = lib.mkIf
    (cfg.enable && builtins.length (builtins.attrNames cfg.startup) != 0)
    {
      xdg.dataFile = lib.mkMerge [
        # Autostart scripts
        (lib.mkMerge
          (lib.mapAttrsToList
            (name: script: {
              "plasma-manager/${cfg.startup.scriptsDir}/${builtins.toString script.priority}_${name}.sh" = {
                text = ''
                  #!/bin/sh
                  ${script.text}
                '';
                executable = true;
              };
            })
            cfg.startup.autoStartScript)
        )
        # Datafiles
        (lib.mkMerge
          (lib.mapAttrsToList
            (name: content: {
              "plasma-manager/${cfg.startup.dataDir}/${name}" = {
                text = content;
              };
            })
            cfg.startup.dataFile)
        )
        # Autostart script runner
        {
          "plasma-manager/${topScriptName}" = {
            text = ''
              #!/bin/sh
              for script in ${config.xdg.dataHome}/plasma-manager/${cfg.startup.scriptsDir}/*.sh; do
                  [ -x "$script" ] && $script
              done
            '';
            executable = true;
          };
        }
      ];

      xdg.configFile."autostart/plasma-manager-autostart.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Plasma Manager theme application
        Exec=${config.xdg.dataHome}/plasma-manager/${topScriptName}
        X-KDE-autostart-condition=ksmserver
      '';
    };
}
