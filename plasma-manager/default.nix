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
  cargoHash = "sha256-cXuB/Bkl8wI8a7Y6SkLnXzbJCu/r+yKqG4H4QvAG85E=";

  meta = {
    description = "plasma-manager command-line interface";
    homepage = "https://github.com/nix-community/plasma-manager";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.HeitorAugustoLN ];
    mainProgram = "plasma-manager";
    platforms = lib.platforms.linux;
  };
}
