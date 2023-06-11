# Global hotkeys (user-defined keyboard shortcuts):
{ config, lib, ... }:
let
  cfg = config.programs.plasma;

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
        description = "The key that triggers the action.";
      };

      command = lib.mkOption {
        type = lib.types.str;
        description = "The command to execute.";
      };
    };
  };

  # Create a hotkey attribute set from the given command.  The idx
  # parameter is the index within the hotkey list for this command.
  commandToHotkey = cmd: idx: {
    inherit (cmd) name comment;

    triggers = [{
      Key = cmd.key;
      Type = "SHORTCUT";
      Uuid = "{" + builtins.hashString "sha256" (builtins.toString idx + cmd.name) + "}";
    }];

    actions = [{
      CommandURL = cmd.command;
      Type = "COMMAND_URL";
    }];

    conditions = [ ];
  };

  # Convert a hotkey to an attribute set that can be used with
  # programs.plasma.files:
  hotkeyToSettings = hotkey: idx:
    let
      prefix = "Data_${toString idx}";

      toSection = name: items:
        builtins.listToAttrs
          (lib.imap0
            (jdx: item: {
              name = "${prefix}${name}${toString jdx}";
              value = item;
            })
            items);
    in
    {
      ${prefix} = {
        Comment = hotkey.comment;
        Enabled = true;
        Name = hotkey.name;
        Type = "SIMPLE_ACTION_DATA";
      };

      "${prefix}Conditions".ConditionsCount =
        builtins.length (hotkey.conditions);

      "${prefix}Actions".ActionsCount =
        builtins.length (hotkey.actions);

      "${prefix}Triggers".TriggersCount =
        builtins.length (hotkey.triggers);
    }
    // toSection "Conditions" hotkey.conditions
    // toSection "Actions" hotkey.actions
    // toSection "Triggers" hotkey.triggers;

  # Turn all options in this module into an attribute sets for
  # programs.plasma.files.
  hotkeys =
    let items =
      (map commandToHotkey (builtins.attrValues cfg.hotkeys.commands));
    in
    lib.foldr (a: b: a // b) { Data.DataCount = builtins.length items; }
      (lib.imap1 (idx: hotkey: hotkeyToSettings (hotkey idx) idx) items);
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
      programs.plasma.configFile.khotkeysrc = hotkeys;
    };
}
