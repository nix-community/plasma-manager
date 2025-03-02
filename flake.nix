{
  description = "Manage KDE Plasma with Home Manager";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
      ];

      imports = [ inputs.home-manager.flakeModules.home-manager ];

      flake.homeManagerModules = {
        default = inputs.self.homeManagerModules.plasma-manager;
        plasma-manager = ./modules;
      };

      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        let
          home-manager-module = inputs.home-manager.nixosModules.home-manager;
          plasma-module = inputs.self.homeManagerModules.plasma-manager;
        in
        {
          checks.default = pkgs.callPackage ./test/basic.nix { inherit home-manager-module plasma-module; };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cargo
              clippy
              nixfmt-rfc-style
              rustc
              rustfmt
            ];

            strictDeps = true;
          };

          formatter = pkgs.treefmt;

          packages =
            let
              docs = import ./docs {
                inherit pkgs;
                inherit (pkgs) lib;
              };
            in
            {
              demo =
                (inputs.nixpkgs.lib.nixosSystem {
                  modules = [
                    (import test/demo.nix {
                      inherit home-manager-module plasma-module;
                    })

                    {
                      # TODO: Re-add this
                      # environment.systemPackages = [ self'.packages.rc2nix ];
                      nixpkgs.hostPlatform = system;
                    }
                  ];
                }).config.system.build.vm;

              docs-html = docs.html;
              docs-json = docs.json;

              plasma-manager = pkgs.callPackage ./plasma-manager { };
            };
        };
    };
}
