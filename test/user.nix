{ module
, home-manager
, homeConfig
}:

{ ... }:

{
  imports = [ home-manager.nixosModules.home-manager ];

  users.users.fake = {
    createHome = true;
    isNormalUser = true;
    password = "password";
    group = "users";
  };

  home-manager = {
    useGlobalPkgs = true;

    users.fake = { ... }: {
      imports = [ module homeConfig ];
      home.stateVersion = "23.11";
    };
  };
}
