{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;
  numlockSettings = [ "on" "off" "unchanged" ];

  touchPadType = types.submodule {
    options = {
      enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables or disables the touchpad
        '';
      };
      name = mkOption {
        type = types.str;
        default = null;
        example = "PNP0C50:00 0911:5288 Touchpad";
        description = ''
          The name of the touchpad.
          You can find it out running cat /proc/bus/input/devices | grep -B 1 -i touchpad
        '';
      };
      vendorId = mkOption {
        type = types.str;
        default = null;
        example = "2321";
        description = ''
          The vendor ID of the touchpad.
          You can find it out running cat /proc/bus/input/devices | grep -B 1 -i touchpad
        '';
      };
      productId = mkOption {
        type = types.str;
        default = null;
        example = "21128";
        description = ''
          The product ID of the touchpad.
          You can find it out running cat /proc/bus/input/devices | grep -B 1 -i touchpad
        '';
      };
      disableWhileTyping = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Disables the touchpad while typing
        '';
      };
      leftHanded = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Swap the left and right buttons
        '';
      };
      middleMouseEmulation = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Middle click by pressing the left and right buttons at the same time.
          Activating this increases the click latency by 50ms
        '';
      };
      pointerSpeed = mkOption {
        type = with types; nullOr (numbers.between (-1) 1);
        default = null;
        example = "0";
        description = ''
          How fast the pointer moves
        '';
      };
      naturalScroll = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables natural scrolling for the touchpad.
        '';
      };
      tapToClick = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables tap-to-click for the touchpad.
        '';
      };
    };
  };
  touchPadToConfig = touchpad:
    let
      touchName = touchpad.name;
      touchVendor = touchpad.vendorId;
      touchProduct = touchpad.productId;
    in
    {
      "Libinput/${touchVendor}/${touchProduct}/${lib.escape ["/"] touchName}" = {
        Enabled = touchpad.enable;
        DisableWhileTyping = touchpad.disableWhileTyping;
        LeftHanded = touchpad.leftHanded;
        MiddleMouseEmulation = touchpad.middleMouseEmulation;
        PointerAcceleration = touchpad.pointerSpeed;
        NaturalScroll = touchpad.naturalScroll;
        TapToClick = touchpad.tapToClick;
      };
    };
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
    repeatDelay = mkOption {
      type = with types; nullOr (ints.between 100 5000);
      default = null;
      example = 200;
      description = ''
        How many milliseconds you need to hold a key down before the input
        starts repeating.
      '';
    };
    repeatRate = mkOption {
      type = with types; nullOr (numbers.between 0.20 100.0);
      default = null;
      example = 50.0;
      description = ''
        How quick the inputs should be repeated when holding down a key.
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

  # Touchpads options
  options.programs.plasma.input.touchpads = mkOption {
    type = with types; listOf touchPadType;
    default = [ ];
    example = [
      {
        enable = true;
        name = "PNP0C50:00 0911:5288 Touchpad";
        vendorId = "2321";
        productId = "21128";
        disableWhileTyping = true;
        leftHanded = true;
        middleMouseEmulation = true;
        pointerSpeed = 0;
        naturalScroll = true;
        tapToClick = true;
      }
    ];
    description = ''
      Configure the different touchpads.
    '';
  };

  config.programs.plasma.configFile."kcminputrc" = mkIf (cfg.enable) (mkMerge [
    {
      Keyboard = (lib.filterAttrs (k: v: v != null) {
        NumLock = (lists.findFirstIndex (x: x == cfg.input.keyboard.numlockOnStartup) null numlockSettings);
        RepeatDelay = cfg.input.keyboard.repeatDelay;
        RepeatRate = cfg.input.keyboard.repeatRate;
      });
    }
    (mkMerge (map touchPadToConfig cfg.input.touchpads))
  ]
  );
}
