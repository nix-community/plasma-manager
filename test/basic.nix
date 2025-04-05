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

    assert() {
      file=$1
      shift
      want=$1
      shift
      actual=$(kreadconfig6 --file $file "$@")

      if [ "$actual" != "$want" ]; then
        echo >&2 "ERROR: $@: expected $want but got $actual"
        exit 1
      else
        echo >&2 "OK: got $want"
      fi
    }

    assert kdeglobals false --group KDE --key SingleClick
    # Set with shorthand
    assert kdeglobals 1 --group group --key key1
    # Set with longhand and immutable
    assert kdeglobals 2 --group group --key key2
    # Nested groups, with group containing /
    assert kdeglobals 3 --group escaped/nested --group group --key key3
    # Value and key have leading space
    assert kdeglobals " leading space" --group group --key " leading space"
    # Set outside plasma-manager, value has leading space, group contains /
    assert kdeglobals " value" --group escaped/nested --group group --key untouched
    # Escaped key with shell expansion
    assert kdeglobals "/home/fake" --group group --key 'escaped[$i]'

    assert kwinrc testvalue --group testgroup --key testkey
    assert kwinrc true --group Plugins --key somePluginEnabled
    assert kwinrc MMM --group "org.kde.kdecoration2" --key ButtonsOnLeft
    assert kwinrc A --group "org.kde.kdecoration2" --key ButtonsOnRight
    assert kwinrc "/run/current-system/sw/share/applications/com.github.maliit.keyboard.desktop" --group Wayland --key InputMethod
    
    assert kglobalshortcutsrc 'Meta+F' --group "services" --group "firefox.desktop" --key "new-window"
    assert kglobalshortcutsrc 'bar' --group "services" --group "firefox.desktop" --key "foo"
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

    home-manager.sharedModules = [
      plasma-module
      {
        programs.plasma.shortcuts."services/firefox.desktop"."new-window" = [ "Meta+F" ];
      }
    ];

    home-manager.users.fake =
      { lib, ... }:
      {
        home.stateVersion = "23.11";
        programs.plasma = {
          enable = true;
          workspace.clickItemTo = "select";
          kwin.titlebarButtons.right = [ "maximize" ];
          configFile."kwinrc" = {
            "testgroup"."testkey" = "testvalue";
            "Plugins"."somePluginEnabled" = true;
            "org.kde.kdecoration2".ButtonsOnLeft = "MMM";
            "Wayland"."InputMethod" = "/run/current-system/sw/share/applications/com.github.maliit.keyboard.desktop";
          };
          configFile."kglobalshortcutsrc"."services/firefox.desktop"."foo" = "bar";
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
    machine.wait_for_unit("nix-daemon.socket")

    machine.wait_until_succeeds(
        "systemctl show -p ActiveState --value home-manager-fake.service | grep -q 'inactive' && " +
        "systemctl show -p Result --value home-manager-fake.service | grep -q 'success'"
    , 10)

    # Run tests:
    machine.succeed("test -e /home/fake/.config/kdeglobals")
    machine.succeed("test -e /home/fake/.config/kwinrc")
    machine.succeed("test -e /home/fake/.config/kglobalshortcutsrc")
    machine.succeed("su - fake -c plasma-basic-test")
  '';
}
