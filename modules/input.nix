{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;
  numlockSettings = [ "on" "off" "unchanged" ];
in
{
  # Keyboard options
  options.programs.plasma.input.keyboard = {
    layouts = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
      example = [ "es" "us" ];
      description = ''
        Keyboard layouts to use.
      '';
    };
    numlockOnStartup = mkOption {
      type = with types; nullOr (enum numlockSettings);
      default = null;
      example = "on";
      description = ''
        Numpad settings at startup.
      '';
    };
  };

  config.programs.plasma.configFile."kxkbrc" = mkIf (cfg.enable) (
    mkMerge [
      (
        mkIf (cfg.input.keyboard.layouts != null) {
          Layout = {
            Use.value = true;
            LayoutList.value = strings.concatStringsSep "," cfg.input.keyboard.layouts;
          };
        }
      )
    ]
  );
  config.programs.plasma.configFile."kcminputrc" = mkIf (cfg.enable) (
    mkMerge [
      (
        # For some reason the numlock settings are here and not on kxkbrc?
        mkIf (cfg.input.keyboard.numlockOnStartup != null) {
          Keyboard.NumLock.value = lists.findFirstIndex (x: x == cfg.input.keyboard.numlockOnStartup) null numlockSettings;
        }
      )
    ]
  );
}
