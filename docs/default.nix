{ pkgs ? import <nixpkgs> { }, lib ? pkgs.lib, ... }:
let
  dontCheckModules = { _module.check = false; };
  modules = [ ../modules dontCheckModules ];

  buildOptionsDocs = (args@{ modules, ... }:
    let
      options = (lib.evalModules {
        inherit modules;
        class = "homeManager";
      }).options;
    in
    pkgs.buildPackages.nixosOptionsDoc {
      inherit options;
    });

  pmOptionsDoc = buildOptionsDocs {
    inherit modules;
  };
  plasma-manager-manual = pkgs.callPackage ./plasma-manager-manual.nix {
    plasma-manager-options = {
      plasma-manager = pmOptionsDoc.optionsJSON;
    };
  };
in
{
  manual = plasma-manager-manual;
}
