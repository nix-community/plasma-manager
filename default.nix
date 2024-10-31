{
  pkgs ? import <nixpkgs> { },
}:
{
  docs = import ./docs {
    inherit pkgs;
    lib = pkgs.lib;
  };
}
