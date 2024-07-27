{ stdenv
, nixos-render-docs
}:
let outputPath = "share/doc/plasma-manager";
in stdenv.mkDerivation {
  name = "plasma-manager-options";

  nativeBuildInputs = [ nixos-render-docs ];

  buildPhase = ''
    mkdir -p out/

    cp ${./options.html} out/options.html

    nixos-render-docs manual html \
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
