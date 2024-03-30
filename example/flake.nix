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

  outputs = inputs@ { nixpkgs, home-manager, plasma-manager, ... }: {
    nixosConfigurations = {
      # Replace jdoeSystem with the name of you configuration
      jdoeSystem = nixpkgs.lib.nixosSystem {
        # Replace with the fitting architecture
        system = "x86_64-linux";
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
  };
}
