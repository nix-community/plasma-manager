# Global hotkeys (user-defined keyboard shortcuts):
{ pkgs, config, lib, ... }:
let
  cfg = config.programs.plasma;

  group = rec {
    name = "plasma-manager-commands";
    desktop = "${name}.desktop";
    description = "Plasma Manager";
  };

  commandType = { name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Command hotkey name.";
      };

      comment = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Optional comment to display in the KDE settings UI.";
      };

      key = lib.mkOption {
        type = lib.types.str;
        description = "The key combination that triggers the action.";
        default = "";
      };

      keys = lib.mkOption {
        type = with lib.types; listOf str;
        description = "The key combinations that trigger the action.";
        default = [ ];
      };

      command = lib.mkOption {
        type = lib.types.str;
        description = "The command to execute.";
      };

      logs.enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Connect command's stdin and stdout to systemd journal with systemd-cat.";
      };

      logs.identifier = lib.mkOption {
        type = lib.types.str;
        default = lib.trivial.pipe name [
          lib.strings.toLower
          (builtins.replaceStrings [ " " ] [ "-" ])
          (n: "${group.name}-${n}")
        ];
        description = "Identifier passed down to systemd-cat.";
      };

      logs.extraArgs = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Additional arguments provided to systemd-cat.";
      };
    };
  };
in
{
  options.programs.plasma.hotkeys = {
    commands = lib.mkOption {
      type = with lib.types; attrsOf (submodule commandType);
      default = { };
      description = "Commands triggered by a keyboard shortcut.";
    };
  };

  config = lib.mkIf
    (cfg.enable && builtins.length (builtins.attrNames cfg.hotkeys.commands) != 0)
    {
      xdg.desktopEntries."${group.name}" = {
        name = group.description;
        noDisplay = true;
        type = "Application";
        actions = lib.mapAttrs
          (_: command: {
            name = command.name;
            exec =
              if command.logs.enabled then
                "${pkgs.systemd}/bin/systemd-cat --identifier=${command.logs.identifier} ${command.logs.extraArgs} ${command.command}"
              else command.command;
          })
          cfg.hotkeys.commands;
      };

      programs.plasma.configFile."kglobalshortcutsrc"."${group.desktop}" = {
        _k_friendly_name.value = group.description;
      } // lib.attrsets.mapAttrs
        (_: command:
          let
            keys = command.keys ++ lib.optionals (command.key != "") [ command.key ];
          in
          {
            value = lib.concatStringsSep "," [
              (lib.concatStringsSep "\t" (map (lib.escape [ "," ]) keys))
              "" # List of default keys, not needed.
              command.comment
            ];
          })
        cfg.hotkeys.commands;
    };
}
