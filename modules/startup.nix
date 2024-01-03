# Allows to run commands/scripts at startup (this is used by some of the other
# modules, which may need to do this, but can also be used on its own)
{ config, lib, ... }:
let
  cfg = config.programs.plasma;
  topScriptName = "run_all.sh";
in
{
  options.programs.plasma.startup = {
    autoStartScript = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Commands/scripts to be run at startup.";
    };
    scriptsDir = lib.mkOption {
      type = lib.types.str;
      default = "scripts";
      description = "The name of the subdirectory where the scripts should be.";
    };
  };

  config = lib.mkIf
    (cfg.enable && builtins.length (builtins.attrNames cfg.startup) != 0)
    {
      xdg.dataFile = lib.mkMerge [
        (lib.mkMerge
          (lib.mapAttrsToList
            (name: content: {
              "plasma-manager/${cfg.startup.scriptsDir}/${name}.sh" = {
                text = ''
                  #!/bin/sh
                  ${content}
                '';
                executable = true;
              };
            })
            cfg.startup.autoStartScript)
        )
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

      xdg.configFile."autostart/plasma-manager-apply-themes.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Plasma Manager theme application
        Exec=${config.xdg.dataHome}/plasma-manager/${topScriptName}
        X-KDE-autostart-condition=ksmserver
      '';
    };
}
