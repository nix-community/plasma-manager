{ testers, home-manager-module, plasma-module, writeShellScriptBin, libsForQt5 }:
let
  script = writeShellScriptBin "plasma-basic-test" ''
    set -eu

    export XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-$HOME/.config}
    export PATH=${libsForQt5.kconfig}/bin:$PATH

    kread_global() {
      kreadconfig5 --file $XDG_CONFIG_HOME/kdeglobals --group $1 --key $2
    }

    assert_eq() {
      actual=$(kread_global "$1" "$2")

      if [ "$actual" != "$3" ]; then
        echo >&2 "ERROR: $1.$2: expected $3 but got $actual"
        exit 1
      fi
    }

    assert_eq KDE SingleClick false
    assert_eq General AllowKDEAppsToRememberWindowPositions true
  '';
in
testers.nixosTest {
  name = "plasma-basic";

  nodes.machine = {
    environment.systemPackages = [ script ];
    imports = [ home-manager-module ];

    users.users.fake = {
      createHome = true;
      isNormalUser = true;
    };

    home-manager.users.fake = {
      home.stateVersion = "23.11";
      imports = [ plasma-module ];
      programs.plasma = {
        enable = true;
        workspace.clickItemTo = "select";
      };
    };
  };

  testScript = ''
    # Boot:
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-fake.service")

    # Run tests:
    machine.succeed("test -e /home/fake/.config/kdeglobals")
    machine.succeed("su - fake -c plasma-basic-test")
  '';
}
