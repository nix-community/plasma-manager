{ lib, ... }:
let
  colorEffectsKeys = [
    "ChangeSelectionColor"
    "Color"
    "ColorAmount"
    "ColorEffect"
    "ContrastAmount"
    "ContrastEffect"
    "Enable"
    "IntensityAmount"
    "IntensityEffect"
  ];
  colorUIKeys = [
    "BackgroundAlternate"
    "BackgroundNormal"
    "DecorationFocus"
    "DecorationHover"
    "ForegroundActive"
    "ForegroundInactive"
    "ForegroundLink"
    "ForegroundNegative"
    "ForegroundNeutral"
    "ForegroundNormal"
    "ForegroundPositive"
    "ForegroundVisited"
  ];
  ignoreKeys = {
    "ColorEffects:Disabled" = colorEffectsKeys;
    "ColorEffects:Inactive" = colorEffectsKeys;
    "Colors:Button" = colorUIKeys;
    "Colors:Complementary" = colorUIKeys;
    "Colors:Header" = colorUIKeys;
    "Colors:Header/Inactive" = colorUIKeys;
    "Colors:Selection" = colorUIKeys;
    "Colors:Tooltip" = colorUIKeys;
    "Colors:View" = colorUIKeys;
    "Colors:Window" = colorUIKeys;
    KDE = [
      "contrast"
      "frameContrast"
    ];
    WM = [
      "activeBackground"
      "activeBlend"
      "activeForeground"
      "inactiveBackground"
      "inactiveBlend"
      "inactiveForeground"
    ];
  };
in
(lib.mkMerge (
  lib.mapAttrsToList (group: keys: {
    "kdeglobals"."${group}" = (
      lib.mkMerge (map (key: { "${key}"."persistent" = (lib.mkDefault true); }) keys)
    );
  }) ignoreKeys
))
