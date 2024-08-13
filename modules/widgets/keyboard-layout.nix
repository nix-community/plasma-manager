{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (keyboard-layout widget): Value ${value} isn't present in the enum. This is a bug")
        enum;
in
{
  keyboardLayout = {
    description = "The keyboard layout indicator widget.";

    opts = {
      displayStyle =
        let enumVals = [ "label" "flag" "labelOverFlag" ];
        in lib.mkOption {
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
        apply = settings: if settings == null then {} else settings;
      };
    };

    convert = { displayStyle, settings }: {
      name = "org.kde.plasma.keyboardlayout";
      config = lib.recursiveUpdate {
        General = lib.filterAttrs (_: v: v != null) {
          inherit displayStyle;
        };
      } settings;
    };
  };
}
