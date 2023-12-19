{ ... }:
{
  programs.plasma = {
    enable = true;

    # Some high-level settings:
    workspace.clickItemTo = "select";

    hotkeys.commands."Launch Konsole" = {
      key = "Meta+Alt+K";
      command = "konsole";
    };

    # Some mid-level settings:
    shortcuts = {
      ksmserver = {
        "Lock Session" = [ "Screensaver" "Meta+Ctrl+Alt+L" ];
      };

      kwin = {
        "Expose" = "Meta+,";
        "Switch Window Down" = "Meta+J";
        "Switch Window Left" = "Meta+H";
        "Switch Window Right" = "Meta+L";
        "Switch Window Up" = "Meta+K";
      };
    };

    # A low-level setting:
    configFile = {
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
      # If a group name has dots you need to escape them
      "kwinrc"."org\\.kde\\.kdecoration2"."ButtonsOnLeft" = "SF";
    };
  };
}
