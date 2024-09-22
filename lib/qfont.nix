{ lib, ... }:
let
  #=== ENUMS ===
  enums = {
    # QFont::StyleHint
    styleHint = rec {
      anyStyle = 5;
      sansSerif = helvetica;
      helvetica = 0;
      serif = times;
      times = 1;
      typewriter = courier;
      courier = 2;
      oldEnglish = 3;
      decorative = oldEnglish;
      monospace = 7;
      fantasy = 8;
      cursive = 6;
      system = 4;
    };

    # QFont::Weight
    weight = {
      thin = 100;
      extraLight = 200;
      light = 300;
      normal = 400;
      medium = 500;
      demiBold = 600;
      bold = 700;
      extraBold = 800;
      black = 900;
    };

    # QFont::Style
    style = {
      normal = 0;
      italic = 1;
      oblique = 2;
    };

    # QFont::Capitalization
    capitalization = {
      mixedCase = 0;
      allUppercase = 1;
      allLowercase = 2;
      smallCaps = 3;
      capitalize = 4;
    };

    # QFont::SpacingType
    spacingType = {
      percentage = 0;
      absolute = 1;
    };

    # QFont::Stretch
    stretch = {
      anyStretch = 0;
      ultraCondensed = 50;
      extraCondensed = 62;
      condensed = 75;
      semiCondensed = 87;
      unstretched = 100;
      semiExpanded = 112;
      expanded = 125;
      extraExpanded = 150;
      ultraExpanded = 200;
    };

    # QFont::StyleStrategy
    # This one's... special.
    styleStrategy = {
      prefer = {
        default = 1;
        bitmap = 2;
        device = 4;
        outline = 8;
        forceOutline = 16;
      };
      matchingPrefer = {
        default = 0;
        exact = 32;
        quality = 64;
      };
      antialiasing = {
        default = 0;
        prefer = 128;
        disable = 256;
      };
      noSubpixelAntialias = 2048;
      preferNoShaping = 4096;
      noFontMerging = 32768;
    };
  };

  inherit (builtins)
    attrNames
    mapAttrs
    removeAttrs
    isAttrs
    ;
  inherit (lib) filterAttrs;

  toEnums = v: lib.types.enum (attrNames v);
in
mapAttrs (_: toEnums) (removeAttrs enums [ "styleStrategy" ])
// {
  styleStrategy = mapAttrs (_: toEnums) (filterAttrs (_: isAttrs) enums.styleStrategy);

  # Converts a font specified by the given attrset to a string representation compatible with
  # QFont::fromString and QFont::toString.
  fontToString =
    {
      family,
      pointSize ? null,
      pixelSize ? null,
      styleHint ? "anyStyle",
      weight ? "normal",
      style ? "normal",
      underline ? false,
      strikeOut ? false,
      fixedPitch ? false,
      capitalization ? "mixedCase",
      letterSpacingType ? "percentage",
      letterSpacing ? 0,
      wordSpacing ? 0,
      stretch ? "anyStretch",
      styleStrategy ? { },
      styleName ? null,
    }:
    let
      inherit (builtins)
        isString
        toString
        foldl'
        bitOr
        ;

      styleStrategy' =
        let
          match = s: enums.styleStrategy.${s}.${styleStrategy.${s} or "default"};
          ifSet = k: if styleStrategy.${k} or false then enums.styleStrategy.${k} else 0;
        in
        foldl' bitOr 0 [
          (match "prefer")
          (match "matchingPrefer")
          (match "antialiasing")
          (ifSet "noSubpixelAntialias")
          (ifSet "preferNoShaping")
          (ifSet "noFontMerging")
        ];

      sizeToString = s: if s == null then "-1" else toString s;

      numOrEnum = attrs: s: if isString s then toString attrs.${s} else toString s;

      zeroOrOne = b: if b then "1" else "0";
    in
    assert lib.assertMsg (lib.xor (pointSize != null) (
      pixelSize != null
    )) "Exactly one of `pointSize` and `pixelSize` has to be set.";
    builtins.concatStringsSep "," (
      [
        family
        (sizeToString pointSize)
        (sizeToString pixelSize)
        (toString enums.styleHint.${styleHint})
        (numOrEnum enums.weight weight)
        (numOrEnum enums.style style)
        (zeroOrOne underline)
        (zeroOrOne strikeOut)
        (zeroOrOne fixedPitch)
        "0"
        (toString enums.capitalization.${capitalization})
        (toString enums.spacingType.${letterSpacingType})
        (toString letterSpacing)
        (toString wordSpacing)
        (numOrEnum enums.stretch stretch)
        (toString styleStrategy')
      ]
      ++ lib.optional (styleName != null) styleName
    );
}
