{ config, lib, ... }:

let
  cfg = config.programs.plasma;
  numlockSettings = [
    "on"
    "off"
    "unchanged"
  ];
  switchModes = [
    "global"
    "desktop"
    "winClass"
    "window"
  ];

  scrollMethods = {
    twoFingers = 1;
    touchPadEdges = 2;
  };
  rightClickMethods = {
    bottomRight = 1;
    twoFingers = 2;
  };

  capitalizeWord =
    word:
    let
      firstLetter = builtins.substring 0 1 word;
      rest = builtins.substring 1 (builtins.stringLength word - 1) word;
    in
    "${lib.toUpper firstLetter}${rest}";

  layoutType = lib.types.submodule {
    options = {
      layout = lib.mkOption {
        type = lib.types.str;
        example = "us";
        description = ''
          Keyboard layout.
        '';
      };
      variant = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "eng";
        description = ''
          Keyboard layout variant.
        '';
        apply = builtins.toString;
      };
      displayName = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "us";
        description = ''
          Keyboard layout display name.
        '';
        apply = builtins.toString;
      };
    };
  };

  touchPadType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable the touchpad.
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "PNP0C50:00 0911:5288 Touchpad";
        description = ''
          The name of the touchpad.

          This can be found by looking at the `Name` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the touchpad.
        '';
      };
      vendorId = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "0911";
        description = ''
          The vendor ID of the touchpad.

          This can be found by looking at the `Vendor` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the touchpad.
        '';
      };
      productId = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "5288";
        description = ''
          The product ID of the touchpad.

          This can be found by looking at the `Product` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the touchpad.
        '';
      };
      disableWhileTyping = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to disable the touchpad while typing.
        '';
      };
      leftHanded = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to swap the left and right buttons.
        '';
      };
      middleButtonEmulation = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to enable middle mouse click emulation by pressing the left and right buttons at the same time.
          Activating this increases the click latency by 50ms.
        '';
      };
      pointerSpeed = lib.mkOption {
        type = with lib.types; nullOr (numbers.between (-1) 1);
        default = null;
        example = "0";
        description = ''
          How fast the pointer moves.
        '';
      };
      naturalScroll = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable natural scrolling for the touchpad.
        '';
      };
      tapToClick = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable tap-to-click for the touchpad.
        '';
      };
      tapAndDrag = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable tap-and-drag for the touchpad.
        '';
      };
      tapDragLock = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable the tap-and-drag lock for the touchpad.
        '';
      };
      scrollMethod = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames scrollMethods));
        default = null;
        example = "touchPadEdges";
        description = ''
          Configure how scrolling is performed on the touchpad.
        '';
        apply = method: if (method == null) then null else scrollMethods."${method}";
      };
      rightClickMethod = lib.mkOption {
        type = with lib.types; nullOr (enum (builtins.attrNames rightClickMethods));
        default = null;
        example = "twoFingers";
        description = ''
          Configure how right-clicking is performed on the touchpad.
        '';
        apply = method: if (method == null) then null else rightClickMethods."${method}";
      };
      twoFingerTap = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "rightClick"
            "middleClick"
          ]);
        default = null;
        example = "twoFingers";
        description = ''
          Configure what a two-finger tap maps to on the touchpad.
        '';
        apply = v: if (v == null) then null else (v == "middleClick");
      };
    };
  };
  touchPadToConfig =
    touchpad:
    let
      touchName = touchpad.name;
      touchVendor = builtins.toString (lib.fromHexString touchpad.vendorId);
      touchProduct = builtins.toString (lib.fromHexString touchpad.productId);
    in
    {
      "Libinput/${touchVendor}/${touchProduct}/${lib.escape [ "/" ] touchName}" = {
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

  mouseType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Enables or disables the mouse.
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "Logitech G403 HERO Gaming Mouse";
        description = ''
          The name of the mouse.

          This can be found by looking at the `Name` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the mouse.
        '';
      };
      vendorId = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "046d";
        description = ''
          The vendor ID of the mouse.

          This can be found by looking at the `Vendor` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the mouse.
        '';
      };
      productId = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "c077";
        description = ''
          The product ID of the mouse.

          This can be found by looking at the `Product` attribute in the section in
          the `/proc/bus/input/devices` path belonging to the mouse.
        '';
      };
      leftHanded = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to swap the left and right buttons.
        '';
      };
      middleButtonEmulation = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = false;
        description = ''
          Whether to enable middle mouse click emulation by pressing the left and right buttons at the same time.
          Activating this increases the click latency by 50ms.
        '';
      };
      acceleration = lib.mkOption {
        type = with lib.types; nullOr (numbers.between (-1) 1);
        default = null;
        example = 0.5;
        description = ''
          Set the mouse acceleration.
        '';
      };
      accelerationProfile = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "none"
            "default"
          ]);
        default = null;
        example = "none";
        description = "Set the mouse acceleration profile.";
        apply =
          profile:
          if profile == "none" then
            1
          else if profile == "default" then
            2
          else
            null;
      };
      naturalScroll = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = ''
          Whether to enable natural scrolling for the mouse.
        '';
      };
      scrollSpeed = lib.mkOption {
        type = with lib.types; nullOr (numbers.between 0.1 20);
        default = null;
        example = 1;
        description = ''
          Configure how fast the scroll wheel moves.
        '';
      };
    };
  };

  mouseToConfig =
    mouse:
    let
      mouseName = mouse.name;
      mouseVendor = builtins.toString (lib.fromHexString mouse.vendorId);
      mouseProduct = builtins.toString (lib.fromHexString mouse.productId);
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
  config.assertions = [
    (
      let
        validChars = [
          "0"
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
          "a"
          "b"
          "c"
          "d"
          "e"
          "f"
        ];
        hexChars = hexStr: builtins.tail (lib.reverseList (builtins.tail (lib.splitString "" hexStr)));
        hexCodeInvalid =
          hex:
          !(lib.all (c: builtins.elem (lib.toLower c) validChars) (hexChars hex))
          && (builtins.stringLength hex) > 0;
        allHexCodes = lib.flatten (
          map (t: [
            t.vendorId
            t.productId
          ]) (cfg.input.touchpads ++ cfg.input.mice)
        );
        invalidHexCodes = builtins.filter hexCodeInvalid allHexCodes;
      in
      {
        assertion = (builtins.length invalidHexCodes) == 0;
        message = "Invalid hex-code for product or vendor-ID in the input module in plasma-manager: ${builtins.head invalidHexCodes}";
      }
    )
  ];
  # Keyboard options
  options.programs.plasma.input.keyboard = {
    model = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "pc104";
      description = ''
        Keyboard model.
      '';
    };
    switchingPolicy = lib.mkOption {
      type = with lib.types; nullOr (enum switchModes);
      default = null;
      example = "global";
      description = ''
        Switching policy for keyboard layouts.
      '';
      apply = policy: if policy == null then null else capitalizeWord policy;
    };
    layouts = lib.mkOption {
      type = with lib.types; nullOr (listOf layoutType);
      default = null;
      example = [
        { layout = "us"; }
        {
          layout = "ca";
          variant = "eng";
        }
        {
          layout = "us";
          variant = "intl";
          displayName = "usi";
        }
      ];
      description = ''
        Keyboard layouts to use.
      '';
    };
    numlockOnStartup = lib.mkOption {
      type = with lib.types; nullOr (enum numlockSettings);
      default = null;
      example = "on";
      description = ''
        Numpad settings at startup.
      '';
    };
    repeatDelay = lib.mkOption {
      type = with lib.types; nullOr (ints.between 100 5000);
      default = null;
      example = 200;
      description = ''
        Configure how many milliseconds a key must be held down for before the input
        starts repeating.
      '';
    };
    repeatRate = lib.mkOption {
      type = with lib.types; nullOr (numbers.between 0.2 100.0);
      default = null;
      example = 50.0;
      description = ''
        Configure how quickly the inputs should be repeated when holding down a key.
      '';
    };
    options = lib.mkOption {
      type = with lib.types; nullOr (listOf str);
      default = null;
      example = [
        "altwin:meta_alt"
        "caps:shift"
        "custom:types"
      ];
      description = ''
        Keyboard options.
      '';
    };
  };

  config.programs.plasma.configFile."kxkbrc" = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      (lib.mkIf (cfg.input.keyboard.layouts != null) {
        Layout = {
          Use.value = true;
          LayoutList.value = lib.concatStringsSep "," (map (l: l.layout) cfg.input.keyboard.layouts);
          VariantList.value = lib.concatStringsSep "," (map (l: l.variant) cfg.input.keyboard.layouts);
          DisplayNames.value = lib.concatStringsSep "," (map (l: l.displayName) cfg.input.keyboard.layouts);
        };
      })
      (lib.mkIf (cfg.input.keyboard.options != null) {
        Layout = {
          ResetOldOptions.value = true;
          Options.value = lib.concatStringsSep "," cfg.input.keyboard.options;
        };
      })
      (lib.mkIf (cfg.input.keyboard.model != null) {
        Layout = {
          Model.value = cfg.input.keyboard.model;
        };
      })
      (lib.mkIf (cfg.input.keyboard.switchingPolicy != null) {
        Layout = {
          SwitchMode.value = cfg.input.keyboard.switchingPolicy;
        };
      })
    ]
  );

  # Touchpads options
  options.programs.plasma.input.touchpads = lib.mkOption {
    type = with lib.types; listOf touchPadType;
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

  options.programs.plasma.input.mice = lib.mkOption {
    type = with lib.types; listOf mouseType;
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

  config.programs.plasma.configFile."kcminputrc" = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      {
        Keyboard = (
          lib.filterAttrs (k: v: v != null) {
            NumLock = (
              lib.lists.findFirstIndex (x: x == cfg.input.keyboard.numlockOnStartup) null numlockSettings
            );
            RepeatDelay = cfg.input.keyboard.repeatDelay;
            RepeatRate = cfg.input.keyboard.repeatRate;
          }
        );
      }
      (lib.mkMerge (map touchPadToConfig cfg.input.touchpads))
      (lib.mkMerge (map mouseToConfig cfg.input.mice))
    ]
  );
}
