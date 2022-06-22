{
  description = "Manage KDE Plasma with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";

    home-manager.url = "github:nix-community/home-manager/release-22.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, ... }:
    let
      # List of systems we run NixOS tests for:
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Function to generate a set based on supported systems:
      forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

      # Like `forAllSystems` except just those support NixOS tests:
      forQemuSystems = inputs.nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Attribute set of nixpkgs for each system:
      nixpkgsFor = forAllSystems (system:
        import inputs.nixpkgs { inherit system; });
    in
    {
      homeManagerModules.plasma = { ... }: {
        imports = [ ./modules ];
      };

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          default = self.packages.${system}.rc2nix;

          rc2nix = pkgs.writeShellApplication {
            name = "rc2nix";
            runtimeInputs = with pkgs; [ ruby ];
            text = ''ruby ${script/rc2nix.rb} "$@"'';
          };
        });

      apps = forAllSystems (system:
        {
          default = self.apps.${system}.rc2nix;

          rc2nix = {
            type = "app";
            program = "${self.packages.${system}.rc2nix}/bin/rc2nix";
          };
        });

      checks = forQemuSystems (system:
        let test = path: import path {
          pkgs = nixpkgsFor.${system};
          home-manager = inputs.home-manager;
          module = self.homeManagerModules.plasma;
        };
        in
        {
          default = test ./test/basic.nix;
        });
    };
}
