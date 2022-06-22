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
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Function to generate a set based on supported systems:
      forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

      # Attribute set of nixpkgs for each system:
      nixpkgsFor = forAllSystems (system:
        import inputs.nixpkgs { inherit system; });
    in
    {
      homeManagerModules.plasma = { ... }: {
        imports = [ ./modules ];
      };

      checks = forAllSystems (system:
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
