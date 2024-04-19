{ config, lib, pkgs, ... }:

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

  checkThemeNameScript = pkgs.writeShellApplication {
    name = "checkThemeName";
    runtimeInputs = with pkgs; [ jq ];
    text = builtins.readFile ./check-theme-name-free.sh;
  };

  checkThemeName = name:
    ''
      ${checkThemeNameScript}/bin/checkThemeName ${name}
    '';

  script = pkgs.writeScript "kate-check" (checkThemeName cfg.editor.theme.name);
in
{
  options.programs.kate = {
    enable = lib.mkEnableOption ''
      Enable configuration management for kate.
    '';

    package = lib.mkPackageOption pkgs "kate" {
      default = [ "kate" ];
      example = "pkgs.libsForQt5.kate";
      extraDescription = ''
        Which kate package to install. Use `pkgs.libsForQt5.kate` in Plasma5 and
        `pkgs.kdePackages.kate` in Plasma6. Use `null` if home-manager should not install kate
        (use this if you want to manage the settings of this user of a system-wide kate
        installation).
      '';
    };

    # ==================================
    #     INDENTATION
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
        description = ''
          Whether kate should try to detect indentation for each given file and not impose default indentation settings.
        '';
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
      "Auto Detect Indent".value = cfg.editor.indent.autodetect;
      "Indentation Width".value = cfg.editor.indent.width;
      "Tab Handling".value = (tabHandlingMode cfg.editor.indent);
      "Tab Width".value = cfg.editor.tabWidth;
      "Keep Extra Spaces".value = cfg.editor.indent.keepExtraSpaces;
      "ReplaceTabsDyn".value = cfg.editor.indent.replaceWithSpaces;
    };

    "KTextEditor Renderer" = {
      "Show Indentation Lines".value = cfg.editor.indent.showLines;


      # COLORTHEME (cannot define this below)
      # Do pick the theme if the user chose one,
      # Do not touch the theme settings otherwise
      "Auto Color Theme Selection".value = lib.mkIf (cfg.editor.theme.name != "") false;
      "Color Theme".value = lib.mkIf (cfg.editor.theme.name != "") cfg.editor.theme.name;
    };
  };


  # ==================================
  #     COLORTHEME

  options.programs.kate.editor.theme = {
    src = lib.mkOption {
      description = ''
        The path of a theme file for the KDE editor (not the window color scheme).
        Obtain a custom one by using the GUI settings in kate. If you want to use a system-wide
        editor color scheme set this path to null. If you set the metadata.name entry in the file
        to a value that matches the name of a system-wide color scheme undesired behaviour may
        occur. The activation will fail if a theme with the filename `<name of your theme>.theme`
        already exists.'';
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    name = lib.mkOption {
      description = ''
        The name of the theme in use. May be a system theme.
        If a theme file was submitted this setting will be set automatically.
      '';
      type = lib.types.str;
      default = "";
    };
  };

  config.programs.kate.editor.theme = {
    # kate's naming scheme is ${themename}.theme
    # which is why we use the same naming scheme here
    name = lib.mkIf (cfg.enable && null != cfg.editor.theme.src) (lib.mkForce (builtins.fromJSON (builtins.readFile cfg.editor.theme.src))."metadata"."name");
  };

  # This won't override existing files since the home-manager activation fails in that case
  config.xdg.dataFile."${cfg.editor.theme.name}.theme" = lib.mkIf (cfg.enable && null != cfg.editor.theme.src)
    {
      source = cfg.editor.theme.src;
      target = "org.kde.syntax-highlighting/themes/${cfg.editor.theme.name}.theme";
    };

  config = {
    home.packages = lib.mkIf (cfg.enable && cfg.package != null) [ cfg.package ];

    # In case of using a custom theme, check that there is no name collision
    home.activation.checkKateTheme = lib.mkIf (cfg.enable && cfg.editor.theme.src != null) (lib.hm.dag.entryBefore [ "writeBoundary" ]
      # No `$DRY_RUN_CMD`, since even a dryrun should fail if checks fail
      ''
        ${script}
      '');

    # In case of using a system theme, there should be a check that there exists such a theme
    # but I could not figure out where to find them
    # That's why there is no check for now
    # See also [the original PR](https://github.com/pjones/plasma-manager/pull/95#issue-2206192839)
  };


  # ==================================
  #     LSP Servers

  options.programs.kate.lsp.customServers = lib.mkOption {
    default = {};
    type = lib.types.attrs;
    description = ''
      Add more lsp server settings here. Check out the format on the
      [KDE page](https://docs.kde.org/stable5/en/kate/kate/kate-application-plugin-lspclient.html).
      Note that these are only the settings, the packages have to be installed separately.
    '';
  };

  config.xdg.configFile."kate/lspclient/settings.json" = {
    text = builtins.toJSON { servers = cfg.lsp.customServers; };
  };
}
