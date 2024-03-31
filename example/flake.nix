{
  description = "Plasma Manager Example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = inputs@ { nixpkgs, home-manager, plasma-manager, ... }:
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
          ./home.nix

          {
            home = {
              inherit username;
              homeDirectory = "/home/${username}";
            };
          }
        ];
      };

      # Replace `moduleConfig` with the name of you configuration (your `username` or `"username@hostname"`)
      nixosConfigurations.moduleConfig = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # Here you typically also would have your configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];

            # This should point to your home.nix path of course. For an example
            # of this see ./home.nix in this directory.
            home-manager.users.jdoe = import ./home.nix;
          }
        ];
      };
    };
}
