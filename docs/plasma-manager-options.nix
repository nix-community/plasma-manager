{ stdenv
, nixos-render-docs
, plasma-manager-options
, revision
, lib
}:
let
  outputPath = "share/doc/plasma-manager";
in
stdenv.mkDerivation {
  name = "plasma-manager-options";

  nativeBuildInputs = [ nixos-render-docs ];

  src = ./manual;

  buildPhase = ''
    mkdir -p out/

    cp ${./static/style.css} out/style.css

    substituteInPlace options.md \
      --replace \
      '@OPTIONS_JSON@' \
      ${plasma-manager-options}/share/doc/nixos/options.json

    substituteInPlace manual.md \
      --replace \
      '@VERSION@' \
      ${revision}

    nixos-render-docs manual html \
      --manpage-urls ./manpage-urls.json \
      --revision ${lib.trivial.revisionWithDefault revision} \
      --style style.css \
      manual.md \
      out/index.xhtml
  '';

  installPhase = ''
    dest="$out/${outputPath}"
    mkdir -p "$(dirname "$dest")"
    mv out "$dest"
  '';
}
