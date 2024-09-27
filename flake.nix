{
  description = "Manage KDE Plasma with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, ... }:
    let
      # Systems that can run tests:
      supportedSystems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
      ];

      # Function to generate a set based on supported systems:
      forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

      # Attribute set of nixpkgs for each system:
      nixpkgsFor = forAllSystems (system: import inputs.nixpkgs { inherit system; });
    in
    {
      homeManagerModules.plasma-manager =
        { ... }:
        {
          imports = [ ./modules ];
        };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          docs = import ./docs {
            inherit pkgs;
            lib = pkgs.lib;
          };
        in
        {
          default = self.packages.${system}.rc2nix;

          demo =
            (inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                (import test/demo.nix {
                  home-manager-module = inputs.home-manager.nixosModules.home-manager;
                  plasma-module = self.homeManagerModules.plasma-manager;
                })
                (_: { environment.systemPackages = [ self.packages.${system}.rc2nix ]; })
              ];
            }).config.system.build.vm;

          docs-html = docs.html;
          docs-json = docs.json;

          rc2nix = pkgs.writeShellApplication {
            name = "rc2nix";
            runtimeInputs = with pkgs; [ python3 ];
            text = ''python3 ${script/rc2nix.py} "$@"'';
          };
        }
      );

      apps = forAllSystems (system: {
        default = self.apps.${system}.rc2nix;

        demo = {
          type = "app";
          program = "${self.packages.${system}.demo}/bin/run-plasma-demo-vm";
        };

        rc2nix = {
          type = "app";
          program = "${self.packages.${system}.rc2nix}/bin/rc2nix";
        };
      });

      checks = forAllSystems (system: {
        default = nixpkgsFor.${system}.callPackage ./test/basic.nix {
          home-manager-module = inputs.home-manager.nixosModules.home-manager;
          plasma-module = self.homeManagerModules.plasma-manager;
        };
      });

      formatter = forAllSystems (system: nixpkgsFor.${system}.treefmt);

      devShells = forAllSystems (system: {
        default = nixpkgsFor.${system}.mkShell {
          buildInputs = with nixpkgsFor.${system}; [
            nixfmt-rfc-style
            ruby
            ruby.devdoc
            (python3.withPackages (pyPkgs: [
              pyPkgs.python-lsp-server
              pyPkgs.black
              pyPkgs.isort
            ]))
          ];
        };
      });
    };
}
