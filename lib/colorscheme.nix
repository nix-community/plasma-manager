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
    "ForegroundVisited"
    "regroundPositive"
  ];
  ignoreKeys = {
    "ColorEffects:Disabled" = colorEffectsKeys;
    "ColorEffects:Inactive" = colorEffectsKeys;
    "Colors:Button" = colorUIKeys;
    "Colors:Selection" = colorUIKeys;
    "Colors:Tooltip" = colorUIKeys;
    "Colors:View" = colorUIKeys;
    "Colors:Window" = colorUIKeys;
  };
in
(lib.mkMerge (
  lib.mapAttrsToList (group: keys: {
    "kdeglobals"."${group}" = (
      lib.mkMerge (map (key: { "${key}"."persistent" = (lib.mkDefault true); }) keys)
    );
  }) ignoreKeys
))
