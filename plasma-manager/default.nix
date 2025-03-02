{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "plasma-manager";
  version = "0-unstable";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
      ./Cargo.toml
      ./Cargo.lock
    ];
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-+QAvsBBBlRa/8DGPBFx7FmCLNF+vs2zlo/LW12TeTnE=";

  meta = {
    description = "plasma-manager command-line interface";
    homepage = "https://github.com/nix-community/plasma-manager";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.HeitorAugustoLN ];
    mainProgram = "plasma-manager";
    platforms = lib.platforms.linux;
  };
}
