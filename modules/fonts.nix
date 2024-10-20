{ lib, config, ... }:
let
  inherit (lib) mkIf mkOption types;
  qfont = import ../lib/qfont.nix { inherit lib; };

  styleStrategyType = types.submodule {
    options = with qfont.styleStrategy; {
      prefer = mkOption {
        type = prefer;
        default = "default";
        description = ''
          Which type of font is preferred by the font when finding an appropriate default family.

          `default`, `bitmap`, `device`, `outline`, `forceOutline` correspond to the
          `PreferDefault`, `PreferBitmap`, `PreferDevice`, `PreferOutline`, `ForceOutline` enum flags
          respectively.
        '';
      };
      matchingPrefer = mkOption {
        type = matchingPrefer;
        default = "default";
        description = ''
          Whether the font matching process prefers exact matches, or best quality matches.

          `default` corresponds to not setting any enum flag, and `exact` and `quality`
          correspond to `PreferMatch` and `PreferQuality` enum flags respectively.
        '';
      };
      antialiasing = mkOption {
        type = antialiasing;
        default = "default";
        description = ''
          Whether antialiasing is preferred for this font.

          `default` corresponds to not setting any enum flag, and `prefer` and `disable`
          correspond to `PreferAntialias` and `NoAntialias` enum flags respectively.
        '';
      };
      noSubpixelAntialias = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If set to `true`, this font will try to avoid subpixel antialiasing.

          Corresponds to the `NoSubpixelAntialias` enum flag.
        '';
      };
      noFontMerging = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If set to `true`, this font will not try to find a substitute font when encountering missing glyphs.

          Corresponds to the `NoFontMerging` enum flag.
        '';
      };
      preferNoShaping = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If set to true, this font will not try to apply shaping rules that may be required for some scripts
          (e.g. Indic scripts), increasing performance if these rules are not required.

          Corresponds to the `PreferNoShaping` enum flag.
        '';
      };
    };
  };

  fontType = types.submodule {
    options = {
      family = mkOption {
        type = types.str;
        description = "The font family of this font.";
        example = "Noto Sans";
      };
      pointSize = mkOption {
        type = types.nullOr types.numbers.positive;
        default = null;
        description = ''
          The point size of this font.

          Could be a decimal, but usually an integer. Mutually exclusive with pixel size.
        '';
      };
      pixelSize = mkOption {
        type = types.nullOr types.ints.u16;
        default = null;
        description = ''
          The pixel size of this font.

          Mutually exclusive with point size.
        '';
      };
      styleHint = mkOption {
        type = qfont.styleHint;
        default = "anyStyle";
        description = ''
          The style hint of this font.

          See https://doc.qt.io/qt-6/qfont.html#StyleHint-enum for more.
        '';
      };
      weight = mkOption {
        type = types.either (types.ints.between 1 1000) qfont.weight;
        default = "normal";
        description = ''
          The weight of the font, either as a number between 1 to 1000 or as a pre-defined weight string.

          See https://doc.qt.io/qt-6/qfont.html#Weight-enum for more.
        '';
      };
      style = mkOption {
        type = qfont.style;
        default = "normal";
        description = "The style of the font.";
      };
      underline = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the font is underlined.";
      };
      strikeOut = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the font is struck out.";
      };
      fixedPitch = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the font has a fixed pitch.";
      };
      capitalization = mkOption {
        type = qfont.capitalization;
        default = "mixedCase";
        description = ''
          The capitalization settings for this font.

          See https://doc.qt.io/qt-6/qfont.html#Capitalization-enum for more.
        '';
      };
      letterSpacingType = mkOption {
        type = qfont.spacingType;
        default = "percentage";
        description = ''
          Whether to use percentage or absolute spacing for this font.

          See https://doc.qt.io/qt-6/qfont.html#SpacingType-enum for more.
        '';
      };
      letterSpacing = mkOption {
        type = types.number;
        default = 0;
        description = ''
          The amount of letter spacing for this font.

          Could be a percentage or an absolute spacing change (positive increases spacing, negative decreases spacing),
          based on the selected `letterSpacingType`.
        '';
      };
      wordSpacing = mkOption {
        type = types.number;
        default = 0;
        description = ''
          The amount of word spacing for this font, in pixels.

          Positive values increase spacing while negative ones decrease spacing.
        '';
      };
      stretch = mkOption {
        type = types.either (types.ints.between 1 4000) qfont.stretch;
        default = "anyStretch";
        description = ''
          The stretch factor for this font, as an integral percentage (i.e. 150 means a 150% stretch),
          or as a pre-defined stretch factor string.
        '';
      };
      styleStrategy = mkOption {
        type = styleStrategyType;
        default = { };
        description = ''
          The strategy for matching similar fonts to this font.

          See https://doc.qt.io/qt-6/qfont.html#StyleStrategy-enum for more.
        '';
      };
      styleName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The style name of this font, overriding the `style` and `weight` parameters when set.
          Used for special fonts that have styles beyond traditional settings.
        '';
      };
    };
  };

  inherit (config.programs.plasma) enable;
  cfg = lib.filterAttrs (_: v: v != null) config.programs.plasma.fonts;
in
{
  options.programs.plasma.fonts = {
    general = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The main font for the Plasma desktop.";
      example = lib.literalExpression ''
        {
          family = "Noto Sans";
          pointSize = 11;
        }
      '';
    };
    fixedWidth = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The fixed width or monospace font for the Plasma desktop.";
      example = lib.literalExpression ''
        {
          family = "Iosevka";
          pointSize = 11;
        }
      '';
    };
    small = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The font used for very small text.";
      example = lib.literalExpression ''
        {
          family = "Noto Sans";
          pointSize = 8;
        }
      '';
    };
    toolbar = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The font used for toolbars.";
      example = lib.literalExpression ''
        {
          family = "Noto Sans";
          pointSize = 10;
        }
      '';
    };
    menu = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The font used for menus.";
      example = lib.literalExpression ''
        {
          family = "Noto Sans";
          pointSize = 10;
        }
      '';
    };
    windowTitle = mkOption {
      type = types.nullOr fontType;
      default = null;
      description = "The font used for window titles.";
      example = lib.literalExpression ''
        {
          family = "Noto Sans";
          pointSize = 10;
        }
      '';
    };
  };

  config.programs.plasma.configFile.kdeglobals =
    let
      mkFont = f: mkIf (enable && builtins.hasAttr f cfg) (qfont.fontToString cfg.${f});
    in
    {
      General = {
        font = mkFont "general";
        fixed = mkFont "fixedWidth";
        smallestReadableFont = mkFont "small";
        toolBarFont = mkFont "toolbar";
        menuFont = mkFont "menu";
      };
      WM.activeFont = mkFont "windowTitle";
    };
}
