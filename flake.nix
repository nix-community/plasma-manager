{
  description = "Manage KDE Plasma with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, ... }:
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
      nixpkgsFor = forAllSystems (system:
        import inputs.nixpkgs { inherit system; });
    in
    {
      homeManagerModules.plasma-manager = { ... }: {
        imports = [ ./modules ];
      };

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          default = self.packages.${system}.rc2nix;

          demo = (inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              (import test/demo.nix {
                home-manager-module = inputs.home-manager.nixosModules.home-manager;
                plasma-module = self.homeManagerModules.plasma-manager;
              })
              (_: {environment.systemPackages = [ self.packages.${system}.rc2nix]; })
            ];
          }).config.system.build.vm;

          rc2nix = pkgs.writeShellApplication {
            name = "rc2nix";
            runtimeInputs = with pkgs; [ ruby ];
            text = ''ruby ${script/rc2nix.rb} "$@"'';
          };
        });

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

      checks = forAllSystems (system:
        {
          default = nixpkgsFor.${system}.callPackage ./test/basic.nix {
            home-manager-module = inputs.home-manager.nixosModules.home-manager;
            plasma-module = self.homeManagerModules.plasma-manager;
          };
        });

      devShells = forAllSystems (system: {
        default = nixpkgsFor.${system}.mkShell {
          buildInputs = with nixpkgsFor.${system}; [
            ruby
            ruby.devdoc
          ];
        };
      });
    };
}
