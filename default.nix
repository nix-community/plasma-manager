{
  pkgs ? import <nixpkgs> { },
}:
{
  docs = import ./docs {
    inherit pkgs;
    inherit (pkgs) lib;
  };
}
