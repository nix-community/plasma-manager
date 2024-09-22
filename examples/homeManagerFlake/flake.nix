{
  description = "Plasma Manager Example with standalone home-manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      plasma-manager,
      ...
    }:
    let
      # Replace with your username
      username = "jdoe";

      # Replace with the fitting architecture
      system = "x86_64-linux";
    in
    {
      # Replace `standAloneConfig` with the name of your configuration (your `username` or `"username@hostname"`)
      homeConfigurations.standAloneConfig = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; };

        modules = [
          inputs.plasma-manager.homeManagerModules.plasma-manager

          # Specify the path to your home configuration here:
          ../home.nix

          {
            home = {
              inherit username;
              homeDirectory = "/home/${username}";
            };
          }
        ];
      };
    };
}
