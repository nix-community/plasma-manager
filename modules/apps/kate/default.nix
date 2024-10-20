{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.kate;

  # compute kate's magic TabHandlingMode
  # 0 is not tab & not undoByShiftTab
  # 1 is tab & undoByShiftTab
  # 2 is not tab & undoByShiftTab
  tabHandlingMode =
    indentSettings:
    if (!indentSettings.undoByShiftTab && !indentSettings.tabFromEverywhere) then
      0
    else
      (if (indentSettings.undoByShiftTab && indentSettings.tabFromEverywhere) then 1 else 2);

  checkThemeNameScript = pkgs.writeShellApplication {
    name = "checkThemeName";
    runtimeInputs = with pkgs; [ jq ];
    text = builtins.readFile ./check-theme-name-free.sh;
  };

  checkThemeName = name: ''
    ${checkThemeNameScript}/bin/checkThemeName ${name}
  '';

  script = pkgs.writeScript "kate-check" (checkThemeName cfg.editor.theme.name);

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (
        x: x == value
      ) (throw "getIndexFromEnum (kate): Value ${value} isn't present in the enum. This is a bug.") enum;

  qfont = import ../../../lib/qfont.nix { inherit lib; };

  styleStrategyType = lib.types.submodule {
    options = with qfont.styleStrategy; {
      prefer = lib.mkOption {
        type = prefer;
        default = "default";
        description = ''
          Which type of font is preferred by the font when finding an appropriate default family.

          `default`, `bitmap`, `device`, `outline`, `forceOutline` correspond to the
          `PreferDefault`, `PreferBitmap`, `PreferDevice`, `PreferOutline`, `ForceOutline` enum flags
          respectively.
        '';
      };
      matchingPrefer = lib.mkOption {
        type = matchingPrefer;
        default = "default";
        description = ''
          Whether the font matching process prefers exact matches, or best quality matches.

          `default` corresponds to not setting any enum flag, and `exact` and `quality`
          correspond to `PreferMatch` and `PreferQuality` enum flags respectively.
        '';
      };
      antialiasing = lib.mkOption {
        type = antialiasing;
        default = "default";
        description = ''
          Whether antialiasing is preferred for this font.

          `default` corresponds to not setting any enum flag, and `prefer` and `disable`
          correspond to `PreferAntialias` and `NoAntialias` enum flags respectively.
        '';
      };
      noSubpixelAntialias = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If set to `true`, this font will try to avoid subpixel antialiasing.

          Corresponds to the `NoSubpixelAntialias` enum flag.
        '';
      };
      noFontMerging = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If set to `true`, this font will not try to find a substitute font when encountering missing glyphs.

          Corresponds to the `NoFontMerging` enum flag.
        '';
      };
      preferNoShaping = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If set to `true`, this font will not try to apply shaping rules that may be required for some scripts
          (e.g. Indic scripts), increasing performance if these rules are not required.

          Corresponds to the `PreferNoShaping` enum flag.
        '';
      };
    };
  };

  fontType = lib.types.submodule {
    options = {
      family = lib.mkOption {
        type = lib.types.str;
        description = "The font family of this font.";
        example = "Noto Sans";
      };
      pointSize = lib.mkOption {
        type = lib.types.nullOr lib.types.numbers.positive;
        default = null;
        description = ''
          The point size of this font.

          Could be a decimal, but usually an integer. Mutually exclusive with pixel size.
        '';
      };
      pixelSize = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.u16;
        default = null;
        description = ''
          The pixel size of this font.

          Mutually exclusive with point size.
        '';
      };
      styleHint = lib.mkOption {
        type = qfont.styleHint;
        default = "anyStyle";
        description = ''
          The style hint of this font.

          See https://doc.qt.io/qt-6/qfont.html#StyleHint-enum for more.
        '';
      };
      weight = lib.mkOption {
        type = lib.types.either (lib.types.ints.between 1 1000) qfont.weight;
        default = "normal";
        description = ''
          The weight of the font, either as a number between 1 to 1000 or as a pre-defined weight string.

          See https://doc.qt.io/qt-6/qfont.html#Weight-enum for more.
        '';
      };
      style = lib.mkOption {
        type = qfont.style;
        default = "normal";
        description = "The style of the font.";
      };
      underline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the font is underlined.";
      };
      strikeOut = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the font is struck out.";
      };
      fixedPitch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the font has a fixed pitch.";
      };
      capitalization = lib.mkOption {
        type = qfont.capitalization;
        default = "mixedCase";
        description = ''
          The capitalization settings for this font.

          See https://doc.qt.io/qt-6/qfont.html#Capitalization-enum for more.
        '';
      };
      letterSpacingType = lib.mkOption {
        type = qfont.spacingType;
        default = "percentage";
        description = ''
          Whether to use percentage or absolute spacing for this font.

          See https://doc.qt.io/qt-6/qfont.html#SpacingType-enum for more.
        '';
      };
      letterSpacing = lib.mkOption {
        type = lib.types.number;
        default = 0;
        description = ''
          The amount of letter spacing for this font.

          Could be a percentage or an absolute spacing change (positive increases spacing, negative decreases spacing),
          based on the selected `letterSpacingType`.
        '';
      };
      wordSpacing = lib.mkOption {
        type = lib.types.number;
        default = 0;
        description = ''
          The amount of word spacing for this font, in pixels.

          Positive values increase spacing while negative ones decrease spacing.
        '';
      };
      stretch = lib.mkOption {
        type = lib.types.either (lib.types.ints.between 1 4000) qfont.stretch;
        default = "anyStretch";
        description = ''
          The stretch factor for this font, as an integral percentage (i.e. 150 means a 150% stretch),
          or as a pre-defined stretch factor string.
        '';
      };
      styleStrategy = lib.mkOption {
        type = styleStrategyType;
        default = { };
        description = ''
          The strategy for matching similar fonts to this font.

          See https://doc.qt.io/qt-6/qfont.html#StyleStrategy-enum for more.
        '';
      };
      styleName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The style name of this font, overriding the `style` and `weight` parameters when set.
          Used for special fonts that have styles beyond traditional settings.
        '';
      };
    };
  };
in
{
  options.programs.kate = {
    enable = lib.mkEnableOption ''
      Enable configuration management for Kate, the KDE Advanced Text Editor.
    '';

    package =
      lib.mkPackageOption pkgs
        [
          "kdePackages"
          "kate"
        ]
        {
          nullable = true;
          example = "pkgs.libsForQt5.kate";
          extraDescription = ''
            Which Kate package to be installed by `home-manager`. Use `pkgs.libsForQt5.kate` for Plasma 5 and
            `pkgs.kdePackages.kate` for Plasma 6. Use `null` if `home-manager` should not install Kate.
          '';
        };

    # ==================================
    #     INDENTATION
    editor = {
      tabWidth = lib.mkOption {
        description = "The width of a single tab (`\t`) sign (in number of spaces).";
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
          Whether Kate should try to detect indentation for each given file and not impose default indentation settings.
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
        description = "Whether to unindent the current line by one level with the shortcut Shift+Tab.";
        default = true;
        type = lib.types.bool;
      };

      inputMode =
        let
          enumVals = [
            "normal"
            "vi"
          ];
        in
        lib.mkOption {
          type = lib.types.enum enumVals;
          description = "The input mode for the editor.";
          default = "normal";
          example = "vi";
          apply = getIndexFromEnum enumVals;
        };

      font = lib.mkOption {
        type = fontType;
        default = {
          family = "Hack";
          pointSize = 10;
        };
        example = {
          family = "Fira Code";
          pointSize = 11;
        };
        description = "The font settings for the editor.";
        apply = qfont.fontToString;
      };
    };
  };

  config.assertions = [
    {
      assertion = cfg.editor.indent.undoByShiftTab || (!cfg.editor.indent.tabFromEverywhere);
      message = "Kate does not support both 'undoByShiftTab' to be disabled and 'tabFromEverywhere' to be enabled at the same time.";
    }
  ];

  # ==================================
  #     COLORTHEME
  options.programs.kate.editor.theme = {
    src = lib.mkOption {
      description = ''
        The path of a theme file for the KDE editor (not the window color scheme).
        Obtain a custom one by using the GUI settings in Kate. If you want to use a system-wide
        editor color scheme set this path to null. If you set the metadata.name entry in the file
        to a value that matches the name of a system-wide color scheme undesired behaviour may
        occur. The activation will fail if a theme with the filename `<name of your theme>.theme`
        already exists.
      '';
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
    name = lib.mkIf (cfg.enable && null != cfg.editor.theme.src) (
      lib.mkForce (builtins.fromJSON (builtins.readFile cfg.editor.theme.src))."metadata"."name"
    );
  };

  # This won't override existing files since the home-manager activation fails in that case
  config.xdg.dataFile."${cfg.editor.theme.name}.theme" =
    lib.mkIf (cfg.enable && null != cfg.editor.theme.src)
      {
        source = cfg.editor.theme.src;
        target = "org.kde.syntax-highlighting/themes/${cfg.editor.theme.name}.theme";
      };

  config = {
    home.packages = lib.mkIf (cfg.enable && cfg.package != null) [ cfg.package ];

    # In case of using a custom theme, check that there is no name collision
    home.activation.checkKateTheme = lib.mkIf (cfg.enable && cfg.editor.theme.src != null) (
      lib.hm.dag.entryBefore [ "writeBoundary" ]
        # No `$DRY_RUN_CMD`, since even a dryrun should fail if checks fail
        ''
          ${script}
        ''
    );

    # In case of using a system theme, there should be a check that there exists such a theme
    # but I could not figure out where to find them
    # That's why there is no check for now
    # See also [the original PR](https://github.com/nix-community/plasma-manager/pull/95#issue-2206192839)
  };

  # ==================================
  #     LSP Servers
  options.programs.kate.lsp.customServers = lib.mkOption {
    default = null;
    type = lib.types.nullOr lib.types.attrs;
    description = ''
      Add more LSP server settings here. Check out the format on the
      [Kate Documentation](https://docs.kde.org/stable5/en/kate/kate/kate-application-plugin-lspclient.html).
      Note that these are only the settings; the appropriate packages have to be installed separately.
    '';
  };

  config.xdg.configFile."kate/lspclient/settings.json" = lib.mkIf (cfg.lsp.customServers != null) {
    text = builtins.toJSON { servers = cfg.lsp.customServers; };
  };

  # ==================================
  #     UI
  options.programs.kate.ui.colorScheme = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;

    example = "Krita dark orange";
    description = ''
      The colour scheme of the UI. Leave this setting at `null` in order to
      not override the systems default scheme for for this application.
    '';
  };

  # ==================================
  #     BRACKETS
  options.programs.kate.editor.brackets = {
    characters = lib.mkOption {
      type = lib.types.str;
      default = "<>(){}[]'\"\`";
      example = "<>(){}[]'\"\`*_~";
      description = "This options determines which characters kate will treat as brackets.";
    };
    automaticallyAddClosing = lib.mkEnableOption ''
      When enabled, a closing bracket is automatically inserted upon typing the opening.
    '';
    highlightRangeBetween = lib.mkEnableOption ''
      This option enables automatch highlighting of the lines between an opening and a
      closing bracket when the cursor is adjacent to either.
    '';
    highlightMatching = lib.mkEnableOption ''
      When enabled, and the cursor is adjacent to a closing bracket, and the corresponding
      closing bracket is outside of the currently visible area, then the line of the opening
      bracket and the line directly after will be shown in a small, floating window
      at the top of the text area.
    '';
    flashMatching = lib.mkEnableOption ''
      When this option is enabled, then a bracket will quickly flash whenever the cursor
      moves adjacent to the corresponding bracket.
    '';
  };

  # ==================================
  #     WRITING THE KATERC
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

      "Animate Bracket Matching" = cfg.editor.brackets.flashMatching;

      # Do pick the theme if the user chose one,
      # Do not touch the theme settings otherwise
      "Auto Color Theme Selection" = lib.mkIf (cfg.editor.theme.name != "") false;
      "Color Theme" = lib.mkIf (cfg.editor.theme.name != "") cfg.editor.theme.name;
      "Text Font" = cfg.editor.font;
    };

    "KTextEditor View" = {
      "Chars To Enclose Selection" = {
        value = cfg.editor.brackets.characters;
        escapeValue = false;
      };
      "Bracket Match Preview" = cfg.editor.brackets.highlightMatching;
      "Auto Brackets" = cfg.editor.brackets.automaticallyAddClosing;
      "Input Mode" = cfg.editor.inputMode;
    };

    "UiSettings"."ColorScheme" = lib.mkIf (cfg.ui.colorScheme != null) cfg.ui.colorScheme;
  };
}
