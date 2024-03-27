{
  description = "Plasma Manager Example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
  };

  outputs = inputs:
    let
      system = "x86_64-linux";
      username = "jdoe";
    in
    {
      # Standalone Home Manager Setup:
      homeConfigurations.${username} =
        inputs.home-manager.lib.homeManagerConfiguration {
          # Ensure Plasma Manager is available:
          extraModules = [
            inputs.plasma-manager.homeManagerModules.plasma-manager
          ];

          # Specify the path to your home configuration here:
          configuration = import ./home.nix;

          inherit system username;
          homeDirectory = "/home/${username}";
        };

      # A shell where Home Manager can be used:
      devShells.${system}.default =
        let pkgs = import inputs.nixpkgs { inherit system; }; in
        pkgs.mkShell {
          buildInputs = [
            inputs.home-manager.packages.${system}.home-manager
          ];
        };
    };
}
