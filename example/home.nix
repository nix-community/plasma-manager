{ ... }:
{
  programs.plasma = {
    enable = true;

    # A high-level setting:
    workspace.clickItemTo = "select";

    # A mid-level setting:
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
    files."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };
}
