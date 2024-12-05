{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  qfont = import ../../lib/qfont.nix { inherit lib; };

  mkBoolOption =
    description:
    lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      inherit description;
    };

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (plasmusic-toolbar widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

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
          Whether the font matching process prefers exact matches, of best quality matches.

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
          If set to true, this font will try to avoid subpixel antialiasing.

          Corresponds to the `NoSubpixelAntialias` enum flag.
        '';
      };
      noFontMerging = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If set to true, this font will not try to find a substitute font when encountering missing glyphs.

          Corresponds to the `NoFontMerging` enum flag.
        '';
      };
      preferNoShaping = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If set to true, this font will not try to apply shaping rules that may be required for some scripts
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
        type = with lib.types; nullOr numbers.positive;
        default = null;
        description = ''
          The point size of this font.

          Could be a decimal, but usually an integer. Mutually exclusive with pixel size.
        '';
      };
      pixelSize = lib.mkOption {
        type = with lib.types; nullOr types.ints.u16;
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
        type = with lib.types; either (ints.between 1 1000) qfont.weight;
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
        type = with lib.types; either (ints.between 1 4000) qfont.stretch;
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
        type = with lib.types; nullOr str;
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
  plasmusicToolbar = {
    description = "KDE Plasma widget that shows currently playing song information and provide playback controls.";

    opts = {
      position = lib.mkOption {
        type = positionType;
        example = {
          horizontal = 250;
          vertical = 100;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = lib.mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 100;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      panelIcon = {
        icon = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "view-media-track";
          description = "Icon to show in the panel.";
        };
        albumCover = {
          fallbackToIcon = mkBoolOption "Whether to fallback to icon if cover is not available.";
          useAsIcon = mkBoolOption "Whether to use album cover as icon or not.";
          radius = lib.mkOption {
            type = with lib.types; nullOr (ints.between 0 25);
            default = null;
            example = 8;
            description = "Radius of the album cover icon.";
          };
        };
      };
      playbackSource = lib.mkOption {
        type = with lib.types; nullOr (either (enum [ "auto" ]) str);
        default = null;
        example = "auto";
        description = "Preferred source to use for playback.";
        apply =
          source:
          if source == null then
            { }
          else if source == "auto" then
            {
              choosePlayerAutomatically = true;
            }
          else
            {
              choosePlayerAutomatically = false;
              preferredPlayerIdentity = source;
            };
      };
      songText = {
        maximumWidth = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          example = 200;
          description = "Maximum width of the song text.";
        };
        scrolling = {
          enable = mkBoolOption "Whether to enable scrolling text or not.";
          behavior =
            let
              enumVals = [
                "alwaysScroll"
                "scrollOnHover"
                "alwaysScrollExceptOnHover"
              ];
            in
            lib.mkOption {
              type = with lib.types; nullOr (enum enumVals);
              default = null;
              example = "alwaysScroll";
              description = "Scrolling behavior of the song text.";
              apply = getIndexFromEnum enumVals;
            };
          speed = lib.mkOption {
            type = with lib.types; nullOr (ints.between 1 10);
            default = null;
            example = 3;
            description = "Speed of the scrolling text.";
          };
          resetOnPause = mkBoolOption "Whether to reset the scrolling text when the song is paused or not.";
        };
        displayInSeparateLines = mkBoolOption "Whether to display song information (title and artist) in separate lines or not.";
      };
      musicControls = {
        showPlaybackControls = mkBoolOption "Whether to show playback controls or not.";
        volumeStep = lib.mkOption {
          type = with lib.types; nullOr (ints.between 1 100);
          default = null;
          example = 5;
          description = "Step size for volume control.";
        };
      };
      font = lib.mkOption {
        type = lib.types.nullOr fontType;
        default = null;
        example = {
          family = "Noto Sans";
          pointSize = 10;
        };
        description = "Custom font to use for the widget.";
        apply = font: if font == null then null else qfont.fontToString font;
      };
      background =
        let
          enumVals = [
            "standard"
            "transparent"
            "transparentShadow"
          ];
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum enumVals);
          default = null;
          example = "transparent";
          description = "Widget background type (only for desktop widget)";
          apply =
            background:
            if background == null then
              null
            else
              builtins.elemAt
                [
                  1
                  0
                  4
                ]
                (
                  lib.lists.findFirstIndex (
                    x: x == background
                  ) (throw "plasmusic-toolbar: non-existent background ${background}. This is a bug!") enumVals
                );
        };
      albumCover = {
        albumPlaceholder = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "file:///home/user/placeholder.png";
          description = "Path to the album placeholder image.";
        };
      };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            useCustomFont = true;
          };
        };
        description = ''
          Extra configuration for the widget options.

          See available options at https://github.com/ccatterina/plasmusic-toolbar/blob/main/src/contents/config/main.xml
        '';
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        panelIcon,
        songText,
        musicControls,
        font,
        background,
        albumCover,
        playbackSource,
        settings,
        ...
      }:
      {
        name = "plasmusic-toolbar";
        config = lib.recursiveUpdate {
          General =
            lib.filterAttrs (_: v: v != null) {
              panelIcon = panelIcon.icon;
              useAlbumCoverAsPanelIcon = panelIcon.albumCover.useAsIcon;
              albumCoverRadius = panelIcon.albumCover.radius;
              fallbackToIconWhenArtNotAvailable = panelIcon.albumCover.fallbackToIcon;

              maxSongWidthInPanel = songText.maximumWidth;
              separateText = songText.displayInSeparateLines;

              textScrollingEnabled = songText.scrolling.enable;
              textScrollingBehaviour = songText.scrolling.behavior;
              textScrollingSpeed = songText.scrolling.speed;
              textScrollingResetOnPause = songText.scrolling.resetOnPause;

              commandsInPanel = musicControls.showPlaybackControls;
              volumeStep = musicControls.volumeStep;

              useCustomFont = font != null;
              customFont = font;

              desktopWidgetBg = background;

              albumPlaceholder = albumCover.albumPlaceholder;
            }
            // playbackSource;
        } settings;
      };
  };
}
