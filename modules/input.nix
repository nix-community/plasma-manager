{ config, lib, ... }:

with lib;

let
  cfg = config.programs.plasma;
  numlockSettings = [ "on" "off" "unchanged" ];

  scrollMethods = {
    twoFingers = 1;
    touchPadEdges = 2;
  };
  rightClickMethods = {
    bottomRight = 1;
    twoFingers = 2;
  };

  touchPadType = types.submodule {
    options = {
      enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables or disables the touchpad.
        '';
      };
      name = mkOption {
        type = types.str;
        default = null;
        example = "PNP0C50:00 0911:5288 Touchpad";
        description = ''
          The name of the touchpad.

          This can be found by looking at the Name attribute in the section in
          /proc/bus/input/devices belonging to the touchpad.
        '';
      };
      vendorId = mkOption {
        type = types.str;
        default = null;
        example = "0911";
        description = ''
          The vendor ID of the touchpad.

          This can be found by looking at the Vendor attribute in the section in
          /proc/bus/input/devices belonging to the touchpad.
        '';
      };
      productId = mkOption {
        type = types.str;
        default = null;
        example = "5288";
        description = ''
          The product ID of the touchpad.

          This can be found by looking at the Product attribute in the section
          in /proc/bus/input/devices belonging to the touchpad.
        '';
      };
      disableWhileTyping = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Disables the touchpad while typing.
        '';
      };
      leftHanded = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Swap the left and right buttons.
        '';
      };
      middleButtonEmulation = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Middle click by pressing the left and right buttons at the same time.
          Activating this increases the click latency by 50ms.
        '';
      };
      pointerSpeed = mkOption {
        type = with types; nullOr (numbers.between (-1) 1);
        default = null;
        example = "0";
        description = ''
          How fast the pointer moves.
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
      tapAndDrag = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables tap-and-drag for the touchpad.
        '';
      };
      tapDragLock = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables tap-and-drag lock for the touchpad.
        '';
      };
      scrollMethod = mkOption {
        type = with types; nullOr (enum (builtins.attrNames scrollMethods));
        default = null;
        example = "touchPadEdges";
        description = ''
          How scrolling is performed on the touchpad.
        '';
        apply = method: if (method == null) then null else scrollMethods."${method}";
      };
      rightClickMethod = mkOption {
        type = with types; nullOr (enum (builtins.attrNames rightClickMethods));
        default = null;
        example = "twoFingers";
        description = ''
          How right-clicking is performed on the touchpad.
        '';
        apply = method: if (method == null) then null else rightClickMethods."${method}";
      };
      twoFingerTap = mkOption {
        type = with types; nullOr (enum [ "rightClick" "middleClick" ]);
        default = null;
        example = "twoFingers";
        description = ''
          How right-clicking is performed on the touchpad.
        '';
        apply = v: if (v == null) then null else (v == "middleClick");
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
        MiddleButtonEmulation = touchpad.middleButtonEmulation;
        PointerAcceleration = touchpad.pointerSpeed;
        NaturalScroll = touchpad.naturalScroll;
        TapToClick = touchpad.tapToClick;
        TapAndDrag = touchpad.tapAndDrag;
        TapDragLock = touchpad.tapDragLock;
        ScrollMethod = touchpad.scrollMethod;
        ClickMethod = touchpad.rightClickMethod;
        LmrTapButtonMap = touchpad.twoFingerTap;
      };
    };

  mouseType = types.submodule {
    options = {
      enable = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables or disables the mouse.
        '';
      };
      name = mkOption {
        type = types.str;
        default = null;
        example = "Logitech G403 HERO Gaming Mouse";
        description = ''
          The name of the mouse.

          This can be found by looking at the Name attribute in the section in
          /proc/bus/input/devices belonging to the mouse.
        '';
      };
      vendorId = mkOption {
        type = types.str;
        default = null;
        example = "046d";
        description = ''
          The vendor ID of the mouse.

          This can be found by looking at the Vendor attribute in the section in
          /proc/bus/input/devices belonging to the mouse.
        '';
      };
      productId = mkOption {
        type = types.str;
        default = null;
        example = "c077";
        description = ''
          The product ID of the mouse.

          This can be found by looking at the Product attribute in the section in
          /proc/bus/input/devices belonging to the mouse.
        '';
      };
      leftHanded = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Swap the left and right buttons.
        '';
      };
      middleButtonEmulation = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Middle click by pressing the left and right buttons at the same time.
          Activating this increases the click latency by 50ms.
        '';
      };
      acceleration = mkOption {
        type = with types; nullOr (numbers.between (-1) 1);
        default = null;
        example = 0.5;
        description = ''
          Mouse acceleration.
        '';
      };
      accelerationProfile = mkOption {
        type = with types; nullOr (enum [ "none" "default" ]);
        default = null;
        example = "none";
        description = "Mouse acceleration profile.";
        apply = profile: if profile == "none" then 1 else if profile == "default" then 2 else null;
      };
      naturalScroll = mkOption {
        type = with types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables natural scrolling for the mouse.
        '';
      };
      scrollSpeed = mkOption {
        type = with types; nullOr (numbers.between 0.1 20);
        default = null;
        example = 1;
        description = ''
          How fast the scroll wheel moves.
        '';
      };
    };
  };

  mouseToConfig = mouse:
    let
      mouseName = mouse.name;
      mouseVendor = mouse.vendorId;
      mouseProduct = mouse.productId;
    in
    {
      "Libinput/${mouseVendor}/${mouseProduct}/${mouseName}" = {
        Enabled = mouse.enable;
        LeftHanded = mouse.leftHanded;
        MiddleButtonEmulation = mouse.middleButtonEmulation;
        NaturalScroll = mouse.naturalScroll;
        PointerAcceleration = mouse.acceleration;
        PointerAccelerationProfile = mouse.accelerationProfile;
        ScrollFactor = mouse.scrollSpeed;
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

  options.programs.plasma.input.mice = mkOption {
    type = with types; listOf mouseType;
    default = [ ];
    example = [
      {
        enable = true;
        name = "Logitech G403 HERO Gaming Mouse";
        vendorId = "046d";
        productId = "c08f";
        leftHanded = false;
        middleButtonEmulation = false;
        acceleration = 0.5;
        accelerationProfile = "none";
        naturalScroll = false;
        scrollSpeed = 1;
      }
    ];
    description = ''
      Configure the different mice.
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
    (mkMerge (map mouseToConfig cfg.input.mice))
  ]
  );
}
