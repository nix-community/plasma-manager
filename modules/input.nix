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

  # Trackpad options

  options.programs.plasma.input.touchpad = {
    enable = mkOption {
      type = with types; nullOr bool;
      default = null;
      example = true;
      description = ''
        Enables or disables the trackpad
      '';
    };
    name = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "PNP0C50:00 0911:5288 Touchpad";
      description = ''
        The name of the trackpad.
        You can find it out running cat /proc/bus/input/devices | grep -i touchpad
      '';
    };
    # Plasma writes down the IDs as decimal, I could do the conversion here but I looked how to do it and it's rough
    # We should do this on write_config.py
    # https://github.com/Misterio77/nix-colors/blob/b92df8f5eb1fa20d8e09810c03c9dc0d94ef2820/lib/core/conversions.nix#L87
    vendorId = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "2321";
      description = ''
        The vendor ID of the trackpad, in decimal.
        You can find it out running cat /proc/bus/input/devices | grep -i touchpad
      '';
    };
    productId = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "21128";
      description = ''
        The product ID of the trackpad, in decimal.
        You can find it out running cat /proc/bus/input/devices | grep -i touchpad
      '';
    };
  };

  config.programs.plasma.configFile."kcminputrc" =
    let
      touchName = cfg.input.touchpad.name;
      touchVendor = cfg.input.touchpad.vendorId;
      touchProduct = cfg.input.touchpad.productId;
    in
    mkIf (cfg.enable) (
      mkMerge [
        (
          # For some reason the numlock settings are here and not on kxkbrc?
          mkIf (cfg.input.keyboard.numlockOnStartup != null) {
            Keyboard.NumLock.value = lists.findFirstIndex (x: x == cfg.input.keyboard.numlockOnStartup) null numlockSettings;
          }
        )
        (
          mkIf (cfg.input.touchpad.enable != null) {
            "Libinput/${touchVendor}/${touchProduct}/${touchName}".Enabled.value = cfg.input.touchpad.enable;
          }
        )
      ]
    );
}
