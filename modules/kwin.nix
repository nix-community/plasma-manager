{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;
  validTitlebarButtons = {
    longNames = [
      "more-window-actions"
      "application-menu"
      "on-all-desktops"
      "minimize"
      "maximize"
      "close"
      "help"
      "shade"
      "keep-below-windows"
      "keep-above-windows"
    ];
    shortNames = [
      "M"
      "N"
      "S"
      "I"
      "A"
      "X"
      "H"
      "L"
      "B"
      "F"
    ];
  };

  # Gets a list with long names and turns it into short names
  getShortNames = wantedButtons:
    lists.forEach
      (
        lists.flatten (
          lists.forEach wantedButtons (currentButton:
            lists.remove null (
              lists.imap0
                (index: value:
                  if value == currentButton then "${toString index}" else null
                )
                validTitlebarButtons.longNames
            )
          )
        )
      )
      getShortNameFromIndex;

  # Gets the index and returns the short name in that position
  getShortNameFromIndex = position: builtins.elemAt validTitlebarButtons.shortNames (strings.toInt position);
in
{
  options.programs.plasma.kwin = {
    titlebarButtons.right = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [ "help" "minimize" "maximize" "close" ];
      description = ''
        Title bar buttons to be placed on the right.
      '';
    };
    titlebarButtons.left = mkOption {
      type = with types; nullOr (listOf (enum validTitlebarButtons.longNames));
      default = null;
      example = [ "on-all-desktops" "keep-above-windows" ];
      description = ''
        Title bar buttons to be placed on the left.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Titlebar buttons
    programs.plasma.configFile."kwinrc"."org\\.kde\\.kdecoration2" = mkMerge [
      (
        mkIf (cfg.kwin.titlebarButtons.left != null) {
          "ButtonsOnLeft" = strings.concatStrings (getShortNames cfg.kwin.titlebarButtons.left);
        }
      )
      (
        mkIf (cfg.kwin.titlebarButtons.right != null) {
          "ButtonsOnRight" = strings.concatStrings (getShortNames cfg.kwin.titlebarButtons.right);
        }
      )
    ];
  };
}
