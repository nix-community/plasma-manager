{ home-manager-module, plasma-module }:

{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/virtualisation/qemu-vm.nix")
    home-manager-module
  ];

  config = {
    networking.hostName = "plasma-demo";

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot = {
      growPartition = true;
      loader.timeout = 5;
      kernelParams = [
        "console=ttyS0"
        "boot.shell_on_fail"
      ];
    };

    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];

    services.xserver.enable = true;
    services.displayManager = {
      autoLogin.user = "fake";
      autoLogin.enable = true;
      defaultSession = "plasma";
      sddm.enable = true;
    };
    services.desktopManager.plasma6.enable = true;

    system.stateVersion = "23.11";

    users.users.fake = {
      createHome = true;
      isNormalUser = true;
      password = "password";
      group = "users";
    };

    home-manager.users.fake = {
      home.stateVersion = "22.05";
      imports = [ plasma-module ];
    };
  };
}
