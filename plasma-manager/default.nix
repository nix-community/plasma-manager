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
      ./kconfig-rs/src
      ./kconfig-rs/Cargo.toml
      ./kconfig-rs/Cargo.lock
    ];
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-UkH5KH2Gvi2ruQzS1hDludB5ZRe3r/J8m2oEA5tC+O8=";

  meta = {
    description = "plasma-manager command-line interface";
    homepage = "https://github.com/nix-community/plasma-manager";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.HeitorAugustoLN ];
    mainProgram = "plasma-manager";
    platforms = lib.platforms.linux;
  };
}
