{ pkgs, home-manager, module }:

let
  script = pkgs.writeShellScriptBin "plasma-basic-test" ''
    set -e
    set -u

    export XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-$HOME/.config}
    export PATH=${pkgs.libsForQt5.kconfig}/bin:$PATH

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

  homeConfig = {
    home.packages = [ script ];

    programs.plasma = {
      enable = true;
      workspace.clickItemTo = "select";
    };
  };

  user = import ./user.nix {
    inherit module home-manager homeConfig;
  };
in
pkgs.nixosTest {
  name = "plasma-basic";

  nodes.machine = { ... }: {
    imports = [ user ];
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
