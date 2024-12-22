{ lib, config, ... }:
let
  inherit (lib) mkIf mkOption types;
  qfont = import ../lib/qfont.nix { inherit lib; };
  fontType = import ../lib/fontType.nix { inherit lib; };

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
