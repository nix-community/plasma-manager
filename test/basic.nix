{
  testers,
  home-manager-module,
  plasma-module,
  writeShellScriptBin,
  kdePackages,
}:
let
  script = writeShellScriptBin "plasma-basic-test" ''
    set -eu

    export XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-$HOME/.config}
    export PATH=${kdePackages.kconfig}/bin:$PATH

    kread_global() {
      kreadconfig6 --file $XDG_CONFIG_HOME/kdeglobals "$@"
    }

    assert_eq() {
      want=$1
      shift
      actual=$(kread_global "$@")

      if [ "$actual" != "$want" ]; then
        echo >&2 "ERROR: $@: expected $want but got $actual"
        exit 1
      fi
    }

    assert_eq false --group KDE --key SingleClick
    # Set with shorthand
    assert_eq 1 --group group --key key1
    # Set with longhand and immutable
    assert_eq 2 --group group --key key2
    # Nested groups, with group containing /
    assert_eq 3 --group escaped/nested --group group --key key3
    # Value and key have leading space
    assert_eq " leading space" --group group --key " leading space"
    # Set outside plasma-manager, value has leading space, group contains /
    assert_eq " value" --group escaped/nested --group group --key untouched
    # Escaped key with shell expansion
    assert_eq "/home/fake" --group group --key 'escaped[$i]'
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

    home-manager.users.fake =
      { lib, ... }:
      {
        home.stateVersion = "23.11";
        imports = [ plasma-module ];
        programs.plasma = {
          enable = true;
          workspace.clickItemTo = "select";
          # Test a variety of weird keys and groups
          configFile.kdeglobals = {
            group = {
              " leading space" = " leading space";
              key1 = 1;
              key2 = {
                value = 2;
                immutable = true;
              };
              "escaped[$i]" = {
                value = "\${HOME}";
                shellExpand = true;
              };
            };
            "escaped\\/nested/group" = {
              key3 = 3;
            };
          };
        };
        home.activation.preseed = lib.hm.dag.entryBefore [ "configure-plasma" ] ''
          mkdir -p ~/.config
          cat <<EOF >> ~/.config/kdeglobals
          [escaped/nested][group]
          untouched = \svalue
          EOF
        '';
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
