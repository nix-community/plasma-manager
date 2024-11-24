{
  stdenv,
  nixos-render-docs,
  plasma-manager-options,
  revision,
  lib,
  documentation-highlighter,
}:
let
  outputPath = "share/doc/plasma-manager";
in
stdenv.mkDerivation {
  name = "plasma-manager-options";

  nativeBuildInputs = [ nixos-render-docs ];

  src = ./manual;

  buildPhase = ''
    mkdir -p out/highlightjs

    cp -t out/highlightjs \
      ${documentation-highlighter}/highlight.pack.js \
      ${documentation-highlighter}/LICENSE \
      ${documentation-highlighter}/mono-blue.css \
      ${documentation-highlighter}/loader.js

    cp ${./static/style.css} out/style.css

    substituteInPlace options.md \
      --replace-fail \
      '@OPTIONS_JSON@' \
      ${plasma-manager-options}/share/doc/nixos/options.json

    substituteInPlace manual.md \
      --replace-fail \
      '@VERSION@' \
      ${revision}

    nixos-render-docs manual html \
      --manpage-urls ./manpage-urls.json \
      --revision ${lib.trivial.revisionWithDefault revision} \
      --style style.css \
      --script highlightjs/highlight.pack.js \
      --script highlightjs/loader.js \
      --toc-depth 1 \
      --section-toc-depth 1 \
      manual.md \
      out/index.xhtml
  '';

  installPhase = ''
    dest="$out/${outputPath}"
    mkdir -p "$(dirname "$dest")"
    mv out "$dest"
  '';
}
