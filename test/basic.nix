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
    export PATH="${kdePackages.kconfig}/bin:$PATH"

    assert() {
      if [ $# -lt 4 ]; then
        echo "at least four arguments required"
        exit 1
      fi
      file="$1"
      shift
      want="$1"
      shift
      grpargs=()
      while [ $# -gt 1 ]; do
        grpargs+=(--group "$1")
        shift
      done
      key="$1"
      shift
      actual="$(kreadconfig6 --file "$file" "''${grpargs[@]}" --key "$key")"

      if [ "$actual" != "$want" ]; then
        echo >&2 "FAIL($file|''${grpargs[@]}|$key): Expected \"$want\" but got \"$actual\""
        exit 1
      fi
    }

    #       FILE                EXPECTED          GROUPS ...                    KEY                [COMMENT]
    assert  kglobalshortcutsrc  Meta+F            services firefox.desktop      new-window         # Set with services option
    assert  kglobalshortcutsrc  bar               services firefox.desktop      foo                # Set with configFile option
    assert  kdeglobals          ' leading space'  group                         ' leading space'   # Set with shorthand
    assert  kdeglobals          /home/fake        group                         'escaped[$i]'      # Set with longhand and immutable
    assert  kdeglobals          false             KDE                           SingleClick        # Nested groups, with group containing /
    assert  kdeglobals          ' value'          'escaped/nested' group        untouched          # Value and key have leading space
    assert  kdeglobals          1                 group                         key1               # Set outside plasma-manager, value has leading space, group contains /
    assert  kdeglobals          2                 group                         key2               # Escaped key with shell expansion
    assert  kdeglobals          3                 'escaped/nested' group        key3               #
    assert  foobarrc            somevalue         somegroup                     somekey            #
    assert  foobarrc            ""                nothing                       nothing            #
    assert  kwinrc              /run/current-system/sw/share/applications/com.github.maliit.keyboard.desktop \
                                                  Wayland                       InputMethod        #
    assert  kwinrc              true              Plugins                       somePluginEnabled  #
    assert  kwinrc              A                 org.kde.kdecoration2          ButtonsOnRight     # Set with kwin option
    assert  kwinrc              MMM               org.kde.kdecoration2          ButtonsOnLeft      # Set with configFile option
    assert  kwinrc              testvalue         testgroup                     testkey            #
    assert  kwinrc              Two               Desktops                      Name_2             # Virtual desktop names written declaratively
    assert  kwinrc              '{"layoutDirection":"horizontal","tiles":[{"width":1.0}]}' \
                                                  Tiling Desktop_2 11111111-2222-3333-4444-555555555555 tiles # Auto-detected display UUID uses correct desktop id
    assert  kwinrc              3                 Tiling Desktop_2 11111111-2222-3333-4444-555555555555 padding # Padding written for auto-detected display UUID
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
        programs.plasma.shortcuts."services/firefox.desktop".new-window = [ "Meta+F" ];
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
          kwin.virtualDesktops = {
            desktops = [
              { name = "One"; }
              {
                name = "Two";
                tiling = {
                  padding = 3;
                  tiles = {
                    layoutDirection = "horizontal";
                    tiles = [ { width = 1.0; } ];
                  };
                };
              }
            ];
            rows = 1;
          };
          configFile.kwinrc = {
            testgroup.testkey = "testvalue";
            Plugins.somePluginEnabled = true;
            "org.kde.kdecoration2".ButtonsOnLeft = "MMM";
            Wayland.InputMethod = "/run/current-system/sw/share/applications/com.github.maliit.keyboard.desktop";
          };
          configFile.kglobalshortcutsrc."services/firefox.desktop".foo = "bar";
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
          configFile.foobarrc.somegroup.somekey = "somevalue";
        };
        home.activation.preseed = lib.hm.dag.entryBefore [ "configure-plasma" ] ''
          mkdir -p ~/.config
          cat <<EOF >> ~/.config/kdeglobals
          [escaped/nested][group]
          untouched = \svalue
          EOF
          cat <<EOF > ~/.config/kwinoutputconfig.json
          {
            "outputs": [
              {
                "uuid": "11111111-2222-3333-4444-555555555555"
              }
            ]
          }
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
    machine.succeed("test -e /home/fake/.config/foobarrc")
    machine.succeed("su - fake -c plasma-basic-test")
  '';
}
