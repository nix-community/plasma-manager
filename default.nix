{ pkgs ? import <nixpkgs> { } }:
rec {
  docs = import ./docs {
    inherit pkgs;
    lib = pkgs.lib;
  };
}
