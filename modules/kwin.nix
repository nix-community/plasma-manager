{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.kwin = {
    titlebarButtons.right = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
      example = [ "H" "I" "A" "X" ];
      description = ''
        Title bar buttons to be placed on the right.
      '';
    };
    titlebarButtons.left = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
      example = [ "S" "F" ];
      description = ''
        Title bar buttons to be placed on the left.
      '';
    };
  };

  config = mkIf (cfg.enable) {
    # Titlebar buttons
    programs.plasma.configFile."kwinrc"."org\\.kde\\.kdecoration2" = mkMerge [
      (
        mkIf (cfg.kwin.titlebarButtons.left != null) {
          "ButtonsOnLeft" = strings.concatStrings cfg.kwin.titlebarButtons.left;
        }
      )
      (
        mkIf (cfg.kwin.titlebarButtons.right != null) {
          "ButtonsOnRight" = strings.concatStrings cfg.kwin.titlebarButtons.right;
        }
      )
    ];
  };
}