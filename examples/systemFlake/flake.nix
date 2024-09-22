{
  description = "Plasma Manager Example with system configuration flake";

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
      # Replace `moduleConfig` with the name of you configuration
      nixosConfigurations.moduleConfig = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # We include the system-configuration here as well. Replace this with
          # your own configuration or import your configuration.nix. The demo
          # here is just the bare minimum to get the flake to not fail.
          {
            system.stateVersion = "23.11";
            users.users."${username}".isNormalUser = true;
            fileSystems."/".device = "/dev/sda";
            boot.loader.grub.devices = [ "/dev/sda" ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];

            # This should point to your home.nix path of course. For an example
            # of this see ./home.nix in this directory.
            home-manager.users."${username}" = import ../home.nix;
          }
        ];
      };
    };
}
