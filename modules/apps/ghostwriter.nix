{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.ghostwriter;

  qfont = import ../../lib/qfont.nix { inherit lib; };

  createThemes = lib.attrsets.mapAttrs' (
    name: value:
    lib.attrsets.nameValuePair "ghostwriter/themes/${name}.json" {
      enable = true;
      source = value;
    }
  );

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (ghostwriter): Value ${value} isn't present in the enum. This is a bug")
        enum;

  getBoolFromEnum =
    enum: value:
    if value == null then
      null
    else if (getIndexFromEnum enum value) == 0 then
      false
    else
      true;

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

          See https://doc.qt.io/qt-6/qfont.html#StyleHint-enum for more information.
        '';
      };
      weight = lib.mkOption {
        type = lib.types.either (lib.types.ints.between 1 1000) qfont.weight;
        default = "normal";
        description = ''
          The weight of the font, either as a number between 1 to 1000 or as a pre-defined weight string.

          See https://doc.qt.io/qt-6/qfont.html#Weight-enum for more information.
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
  options.programs.ghostwriter = {
    enable = lib.mkEnableOption ''
      Enable configuration management for Ghostwriter.
    '';

    font = lib.mkOption {
      type = lib.types.nullOr fontType;
      default = null;
      example = {
        family = "Noto Sans";
        pointSize = 12;
      };
      description = ''
        The font to use for Ghostwriter.
      '';
      apply = font: if font == null then null else ''"${qfont.fontToString font}"'';
    };

    locale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "en_US";
      description = ''
        The locale to use for Ghostwriter.
      '';
    };

    package =
      lib.mkPackageOption pkgs
        [
          "kdePackages"
          "ghostwriter"
        ]
        {
          nullable = true;
          example = "pkgs.kdePackages.ghostwriter";
          extraDescription = ''
            Use `pkgs.libsForQt5.ghostwriter` for Plasma 5 and
            `pkgs.kdePackages.ghostwriter` for Plasma 6. Use
            `null` if `home-manager` should not install Ghostwriter.
          '';
        };

    editor = {
      styling = {
        blockquoteStyle =
          let
            enumVals = [
              "simple"
              "italic"
            ];
          in
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum enumVals);
            default = null;
            example = "simple";
            description = "The style of blockquotes.";
            apply = getBoolFromEnum enumVals;
          };
        editorWidth =
          let
            enumVals = [
              "narrow"
              "medium"
              "wide"
              "full"
            ];
          in
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum enumVals);
            default = null;
            example = "medium";
            description = "The width of the editor.";
            apply = getIndexFromEnum enumVals;
          };
        emphasisStyle =
          let
            enumVals = [
              "italic"
              "underline"
            ];
          in
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum enumVals);
            default = null;
            example = "bold";
            description = "The style of emphasis.";
            apply = getBoolFromEnum enumVals;
          };
        focusMode =
          let
            enumVals = [
              "sentence"
              "currentLine"
              "threeLines"
              "paragraph"
              "typewriter"
            ];
          in
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum enumVals);
            default = null;
            example = "sentence";
            description = "The focus mode to use.";
            apply =
              focusMode:
              if focusMode == null then
                null
              else
                builtins.elemAt
                  [
                    1
                    2
                    3
                    4
                    5
                  ]
                  (
                    lib.lists.findFirstIndex (x: x == focusMode)
                      (throw "editor.styling.focusMode: Value ${focusMode} isn't present in the enum. This is a bug.")
                      enumVals
                  );
          };
        useLargeHeadings = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to use large headings.";
        };
      };
      tabulation = {
        insertSpacesForTabs = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Whether to insert spaces for tabs.
          '';
        };
        tabWidth = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = ''
            The width of a tab.
          '';
        };
      };
      typing = {
        automaticallyMatchCharacters = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            example = true;
            description = "Whether to automatically match characters.";
          };
          characters = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = ''\"'([{*_`<'';
            description = "The characters to automatically match.";
            apply = chars: if chars == null then null else ''"${chars}"'';
          };
        };
        bulletPointCycling = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to cycle through bullet points.";
        };
      };
    };

    general = {
      display = {
        hideMenubarInFullscreen = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to hide the menubar in fullscreen mode.";
        };
        interfaceStyle =
          let
            enumVals = [
              "rounded"
              "square"
            ];
          in
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum enumVals);
            default = null;
            example = "rounded";
            description = "The interface style to use for Ghostwriter.";
            apply = getIndexFromEnum enumVals;
          };
        showCurrentTimeInFullscreen = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to show the current time in fullscreen mode.";
        };
        showUnbreakableSpace = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to show unbreakable space.";
        };
      };
      fileSaving = {
        autoSave = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to enable auto-save.";
        };
        backupFileOnSave = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to backup the file on save.";
        };
        backupLocation = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/home/user/.local/share/ghostwriter/backups";
          description = ''
            The location to store backups of the Ghostwriter configuration.
          '';
        };
      };
      session = {
        openLastFileOnStartup = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to open the last file on startup.";
        };
        rememberRecentFiles = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          example = true;
          description = "Whether to remember recent files.";
        };
      };
    };

    preview = {
      codeFont = lib.mkOption {
        type = lib.types.nullOr fontType;
        default = null;
        example = {
          family = "Hack";
          pointSize = 12;
        };
        description = ''
          The code font to use for the preview.
        '';
        apply = font: if font == null then null else ''"${qfont.fontToString font}"'';
      };
      commandLineOptions = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          Additional command line options to pass to the preview command.
        '';
      };
      markdownVariant = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "cmark-gfm";
        description = ''
          The markdown variant to use for the preview.
        '';
      };
      openByDefault = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = ''
          Whether to open the preview by default.
        '';
      };
      textFont = lib.mkOption {
        type = lib.types.nullOr fontType;
        default = null;
        example = {
          family = "Inter";
          pointSize = 12;
        };
        description = ''
          The text font to use for the preview.
        '';
        apply = font: if font == null then null else ''"${qfont.fontToString font}"'';
      };
    };

    spelling = {
      autoDetectLanguage = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = "Whether to auto-detect the language.";
      };
      checkerEnabledByDefault = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = "Whether the checker is enabled by default.";
      };
      ignoreUppercase = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = "Whether to ignore uppercase words.";
      };
      ignoredWords = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = [
          "Amarok"
          "KHTML"
          "NixOS"
        ];
        description = "Words to ignore in the spell checker.";
        apply =
          ignoredWords: if ignoredWords == null then null else builtins.concatStringsSep ", " ignoredWords;
      };
      liveSpellCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = "Whether to enable live spell checking.";
      };
      skipRunTogether = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        example = true;
        description = "Whether to skip run-together words.";
      };
    };

    theme = {
      name = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "Ghostwriter";
        description = ''
          The name of the theme to use.
        '';
      };
      customThemes = lib.mkOption {
        type = with lib.types; attrsOf path;
        default = { };
        description = ''
          Custom themes to be added to the installation. The attribute key is mapped to their name.
          Choose them from `programs.ghostwriter.theme.name`.
        '';
      };
    };

    window.sidebarOpen = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether the sidebar is open by default.";
    };
  };

  config = (
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.spelling.ignoredWords == null || cfg.locale != null;
          message = "ghostwriter: Ignored words can only be set if a locale is set.";
        }
      ];

      home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

      programs.plasma.configFile = {
        "kde.org/ghostwriter.conf" = (
          lib.mkMerge [
            # Font
            (lib.mkIf (cfg.font != null) { Style.editorFont = cfg.font; })

            # Locale
            (lib.mkIf (cfg.locale != null) { Application.locale = cfg.locale; })

            # Editor > Styling
            (lib.mkIf (cfg.editor.styling.blockquoteStyle != null) {
              Style.blockquoteStyle = cfg.editor.styling.blockquoteStyle;
            })
            (lib.mkIf (cfg.editor.styling.emphasisStyle != null) {
              Style.underlineInsteadOfItalics = cfg.editor.styling.emphasisStyle;
            })
            (lib.mkIf (cfg.editor.styling.editorWidth != null) {
              Style.editorWidth = cfg.editor.styling.editorWidth;
            })
            (lib.mkIf (cfg.editor.styling.focusMode != null) {
              Style.focusMode = cfg.editor.styling.focusMode;
            })
            (lib.mkIf (cfg.editor.styling.useLargeHeadings != null) {
              Style.largeHeadings = cfg.editor.styling.useLargeHeadings;
            })

            # Editor > Tabulation
            (lib.mkIf (cfg.editor.tabulation.insertSpacesForTabs != null) {
              Tabs.insertSpacesForTabs = cfg.editor.tabulation.insertSpacesForTabs;
            })
            (lib.mkIf (cfg.editor.tabulation.tabWidth != null) {
              Tabs.tabWidth = cfg.editor.tabulation.tabWidth;
            })

            # Editor > Typing
            (lib.mkIf (cfg.editor.typing.automaticallyMatchCharacters.enable != null) {
              Typing.autoMatchEnabled = cfg.editor.typing.automaticallyMatchCharacters.enable;
            })
            (lib.mkIf (cfg.editor.typing.automaticallyMatchCharacters.characters != null) {
              Typing.autoMatchFilter = {
                value = cfg.editor.typing.automaticallyMatchCharacters.characters;
                escapeValue = false;
              };
            })
            (lib.mkIf (cfg.editor.typing.bulletPointCycling != null) {
              Typing.bulletPointCyclingEnabled = cfg.editor.typing.bulletPointCycling;
            })

            # General > Display
            (lib.mkIf (cfg.general.display.hideMenubarInFullscreen != null) {
              Style.hideMenuBarInFullscreen = cfg.general.display.hideMenubarInFullscreen;
            })
            (lib.mkIf (cfg.general.display.interfaceStyle != null) {
              Style.interfaceStyle = cfg.general.display.interfaceStyle;
            })
            (lib.mkIf (cfg.general.display.showCurrentTimeInFullscreen != null) {
              Style.displayTimeInFullScreen = cfg.general.display.showCurrentTimeInFullscreen;
            })
            (lib.mkIf (cfg.general.display.showUnbreakableSpace != null) {
              style.showUnbreakableSpace = cfg.general.display.showUnbreakableSpace;
            })

            # General > File Saving
            (lib.mkIf (cfg.general.fileSaving.autoSave != null) {
              Save.autoSave = cfg.general.fileSaving.autoSave;
            })
            (lib.mkIf (cfg.general.fileSaving.backupFileOnSave != null) {
              Save.backupFile = cfg.general.fileSaving.backupFileOnSave;
            })
            (lib.mkIf (cfg.general.fileSaving.backupLocation != null) {
              Backup.location = cfg.general.fileSaving.backupLocation;
            })

            # General > Session
            (lib.mkIf (cfg.general.session.openLastFileOnStartup != null) {
              Session.restoreSession = cfg.general.session.openLastFileOnStartup;
            })
            (lib.mkIf (cfg.general.session.rememberRecentFiles != null) {
              Session.rememberFileHistory = cfg.general.session.rememberRecentFiles;
            })

            # Spelling
            (lib.mkIf (cfg.spelling.liveSpellCheck != null) {
              Spelling = {
                liveSpellCheck = cfg.spelling.liveSpellCheck;
              };
            })

            # Preview options
            (lib.mkIf (cfg.preview.codeFont != null) { Preview.codeFont = cfg.preview.codeFont; })
            (lib.mkIf (cfg.preview.commandLineOptions != null) {
              Preview.lastUsedExporterParams = cfg.preview.commandLineOptions;
            })
            (lib.mkIf (cfg.preview.markdownVariant != null) {
              Preview.lastUsedExporter = cfg.preview.markdownVariant;
            })
            (lib.mkIf (cfg.preview.openByDefault != null) {
              Preview.htmlPreviewOpen = cfg.preview.openByDefault;
            })
            (lib.mkIf (cfg.preview.textFont != null) { Preview.textFont = cfg.preview.textFont; })

            # Theme
            (lib.mkIf (cfg.theme.name != null) { Style.theme = cfg.theme.name; })

            # Window
            (lib.mkIf (cfg.window.sidebarOpen != null) { Window.sidebarOpen = cfg.window.sidebarOpen; })
          ]
        );

        "KDE/Sonnet.conf".General = (
          lib.mkMerge [
            (lib.mkIf (cfg.spelling.autoDetectLanguage != null) {
              autodetectLanguage = cfg.spelling.autoDetectLanguage;
            })
            (lib.mkIf (cfg.spelling.checkerEnabledByDefault != null) {
              checkerEnabledByDefault = cfg.spelling.checkerEnabledByDefault;
            })
            (lib.mkIf (cfg.spelling.ignoreUppercase != null) {
              checkUppercase = !cfg.spelling.ignoreUppercase;
            })
            (lib.mkIf (cfg.spelling.ignoredWords != null && cfg.locale != null) {
              "ignore_${cfg.locale}" = cfg.spelling.ignoredWords;
            })
            (lib.mkIf (cfg.locale != null) { defaultLanguage = cfg.locale; })
          ]
        );
      };

      xdg.dataFile = (createThemes cfg.theme.customThemes);
    }
  );
}
