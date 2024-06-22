# Allows to run commands/scripts at startup (this is used by some of the other
# modules, which may need to do this, but can also be used on its own)
{ config, lib, ... }:
let
  cfg = config.programs.plasma;
  topScriptName = "run_all.sh";

  textOption = lib.mkOption {
    type = lib.types.str;
    description = "The content of the startup-script.";
  };
  priorityOption = lib.mkOption {
    type = (lib.types.ints.between 0 8);
    default = 0;
    description = "The priority for the execution of the script. Lower priority means earlier execution.";
  };
  restartServicesOption = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = "Services to restart after the script has been run.";
  };

  startupScriptType = lib.types.submodule {
    options = {
      text = textOption;
      priority = priorityOption;
      restartServices = restartServicesOption;
    };
  };
  desktopScriptType = lib.types.submodule {
    options = {
      text = textOption;
      priority = priorityOption;
      restartServices = restartServicesOption;
      preCommands = lib.mkOption {
        type = lib.types.str;
        description = "Commands to run before the desktop script lines.";
        default = "";
      };
      postCommands = lib.mkOption {
        type = lib.types.str;
        description = "Commands to run after the desktop script lines.";
        default = "";
      };
    };
  };

  createScriptContent = name: sha256sumFile: script: text: {
    "plasma-manager/${cfg.startup.scriptsDir}/${builtins.toString script.priority}_${name}.sh" = {
      text = ''
        #!/bin/sh
        last_update="$(sha256sum ${sha256sumFile})"
        last_update_file=${config.xdg.dataHome}/plasma-manager/last_run_${name}
        if [ -f "$last_update_file" ]; then
          stored_last_update=$(cat "$last_update_file")
        fi

        if ! [ "$last_update" = "$stored_last_update" ]; then
          success=1
          trap 'success=0' ERR
          ${text}
          if [ $success -eq 1 ]; then
            echo "$last_update" > "$last_update_file"
            ${builtins.concatStringsSep "\n" (map (s: "echo ${s} >> ${config.xdg.dataHome}/plasma-manager/services_to_restart") script.restartServices)}
          fi
        fi
      '';
      executable = true;
    };
  };
in
{
  options.programs.plasma.startup = {
    startupScript = lib.mkOption {
      type = lib.types.attrsOf startupScriptType;
      default = { };
      description = "Commands/scripts to be run at startup.";
    };
    desktopScript = lib.mkOption {
      type = lib.types.attrsOf desktopScriptType;
      default = { };
      description = ''
        Plasma desktop scripts to be run exactly once at startup. See
        https://develop.kde.org/docs/plasma/scripting/ for details on plasma
        desktop scripts.
      '';
    };
    dataFile = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = "Datafiles, typically for use in autostart scripts.";
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

  config.xdg = lib.mkIf
    (cfg.enable &&
      (builtins.length (builtins.attrNames cfg.startup.startupScript) != 0 ||
        (builtins.length (builtins.attrNames cfg.startup.desktopScript)) != 0))
    {
      dataFile = lib.mkMerge [
        # Autostart scripts
        (lib.mkMerge
          (lib.mapAttrsToList
            (name: script: createScriptContent name "$0" script script.text)
            cfg.startup.startupScript))
        # Desktop scripts
        (lib.mkMerge
          ((lib.mapAttrsToList
            (name: script:
              let layoutScriptPath = "${config.xdg.dataHome}/plasma-manager/${cfg.startup.dataDir}/desktop_script_${name}.js";
              in createScriptContent "desktop_script_${name}" layoutScriptPath script
                ''
                  ${script.preCommands}
                  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat ${layoutScriptPath})"
                  ${script.postCommands}
                '')
            cfg.startup.desktopScript) ++
          (lib.mapAttrsToList
            (name: content: {
              "plasma-manager/${cfg.startup.dataDir}/desktop_script_${name}.js" = {
                text = content.text;
              };
            })
            cfg.startup.desktopScript)))
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

              services_restart_file="${config.xdg.dataHome}/plasma-manager/services_to_restart"

              # Reset the file keeping track of which scripts to restart.
              # Technically can be put at the end as well (maybe better, at
              # least assuming the file hasn't been tampered with of some sort).
              if [ -f $services_restart_file ]; then rm $services_restart_file; fi

              for script in ${config.xdg.dataHome}/plasma-manager/${cfg.startup.scriptsDir}/*.sh; do
                  [ -x "$script" ] && $script
              done

              # Restart the services
              if [ -f $services_restart_file ]; then
                for service in $(sort $services_restart_file | uniq); do
                  systemctl --user restart $service
                done
              fi
            '';
            executable = true;
          };
        }
      ];

      configFile."autostart/plasma-manager-autostart.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Plasma Manager theme application
        Exec=${config.xdg.dataHome}/plasma-manager/${topScriptName}
        X-KDE-autostart-condition=ksmserver
      '';
    };
}
