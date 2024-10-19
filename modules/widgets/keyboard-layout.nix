{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (keyboard-layout widget): Value ${value} isn't present in the enum. This is a bug")
        enum;
in
{
  keyboardLayout = {
    description = "The keyboard layout indicator widget.";

    opts = {
      position = lib.mkOption {
        type = positionType;
        example = {
          horizontal = 250;
          vertical = 50;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = lib.mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 500;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      displayStyle =
        let
          enumVals = [
            "label"
            "flag"
            "labelOverFlag"
          ];
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum enumVals);
          default = null;
          example = "labelOverFlag";
          description = "Keyboard layout indicator display style.";
          apply = getIndexFromEnum enumVals;
        };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            displayStyle = 1;
          };
        };
        apply = settings: if settings == null then { } else settings;
      };
    };

    convert =
      { displayStyle, settings, ... }:
      {
        name = "org.kde.plasma.keyboardlayout";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) { inherit displayStyle; };
        } settings;
      };
  };
}
