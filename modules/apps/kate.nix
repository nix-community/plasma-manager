{ config, lib, ... }:



let
  cfg = config.programs.kate;
  # compute kate's magic TabHandlingMode
  # 0 is not tab & not undoByShiftTab
  # 1 is tab & undoByShiftTab
  # 2 is not tab & undoByShiftTab
  tabHandlingMode = indentSettings:
    if (!indentSettings.undoByShiftTab && !indentSettings.tabFromEverywhere) then 0 else
    (
      if (indentSettings.undoByShiftTab && indentSettings.tabFromEverywhere) then 1 else
      2
    );
in
{
  options.programs.kate = {
    enable = lib.mkEnableOption ''
      Enable configuration management for kate.
    '';
    editor = {
      tabWidth = lib.mkOption {
        description = "The width of a single tab (''\t) sign (in number of spaces).";
        default = 4;
        type = lib.types.int;
      };

      indent.showLines = lib.mkOption {
        description = "Whether to show the vertical lines that mark each indentation level.";
        default = true;
        type = lib.types.bool;
      };

      indent.width = lib.mkOption {
        description = "The width of each indent level (in number of spaces).";
        default = cfg.editor.tabWidth;
        type = lib.types.int;
      };

      indent.autodetect = lib.mkOption {
        description = "Whether kate should try to detect indentation for each given file and not impose default indentation settings.";
        default = true;
        type = lib.types.bool;
      };

      indent.keepExtraSpaces = lib.mkOption {
        description = "Whether additional spaces that do not match the indent should be kept when adding/removing indentation level. If these are kept (option to true) then indenting 1 space further (with a default of 4 spaces) will be set to 5 spaces.";
        default = false;
        type = lib.types.bool;
      };

      indent.replaceWithSpaces = lib.mkOption {
        description = "Whether all indentation should be automatically converted to spaces.";
        default = false;
        type = lib.types.bool;
      };

      indent.backspaceDecreaseIndent = lib.mkOption {
        description = "Whether the backspace key in the indentation should decrease indentation by a full level always.";
        default = true;
        type = lib.types.bool;
      };

      indent.tabFromEverywhere = lib.mkOption {
        description = "Whether the tabulator key increases intendation independent from the current cursor position.";
        default = false;
        type = lib.types.bool;
      };

      indent.undoByShiftTab = lib.mkOption {
        description = "Whether to unindent the current line by one level with the shortcut Shift+Tab";
        default = true;
        type = lib.types.bool;
      };
    };
  };

  config.assertions = [
    {
      assertion = cfg.editor.indent.undoByShiftTab || (!cfg.editor.indent.tabFromEverywhere);
      message = "Kate does not support both 'undoByShiftTab' to be disabled and 'tabFromEverywhere' to be enabled at the same time.";
    }
  ];

  config.programs.plasma.configFile."katerc" = lib.mkIf cfg.enable {
    "KTextEditor Document" = {
      "Auto Detect Indent" = cfg.editor.indent.autodetect;
      "Indentation Width" = cfg.editor.indent.width;
      "Tab Handling" = (tabHandlingMode cfg.editor.indent);
      "Tab Width" = cfg.editor.tabWidth;
      "Keep Extra Spaces" = cfg.editor.indent.keepExtraSpaces;
      "ReplaceTabsDyn" = cfg.editor.indent.replaceWithSpaces;
    };

    "KTextEditor Renderer" = {
      "Show Indentation Lines" = cfg.editor.indent.showLines;
    };
  };
}
