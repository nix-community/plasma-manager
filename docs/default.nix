{ pkgs, lib, ... }:
let
  dontCheckModules = {
    _module.check = false;
  };
  modules = [
    ../modules
    dontCheckModules
  ];

  githubDeclaration = user: repo: branch: subpath: {
    url = "https://github.com/${user}/${repo}/blob/${branch}/${subpath}";
    name = "<${repo}/${subpath}>";
  };

  pmPath = toString ./..;
  transformOptions =
    opt:
    opt
    // {
      declarations = (
        map (
          decl:
          if (lib.hasPrefix pmPath (toString decl)) then
            (githubDeclaration "nix-community" "plasma-manager" "trunk" (
              lib.removePrefix "/" (lib.removePrefix pmPath (toString decl))
            ))
          else
            decl
        ) opt.declarations
      );
    };

  buildOptionsDocs = (
    args@{ modules, ... }:
    let
      opts =
        (lib.evalModules {
          inherit modules;
          class = "homeManager";
        }).options;
      options = builtins.removeAttrs opts [ "_module" ];
    in
    pkgs.buildPackages.nixosOptionsDoc {
      inherit options;
      inherit transformOptions;
      warningsAreErrors = false;
    }
  );

  pmOptionsDoc = buildOptionsDocs { inherit modules; };
  plasma-manager-options = pkgs.callPackage ./plasma-manager-options.nix {
    nixos-render-docs = pkgs.nixos-render-docs;
    plasma-manager-options = pmOptionsDoc.optionsJSON;
    revision = "latest";
  };
in
{
  html = plasma-manager-options;
  json = pmOptionsDoc.optionsJSON;
}
