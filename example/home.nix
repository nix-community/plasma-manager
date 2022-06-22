{ ... }:
{
  programs.plasma = {
    enable = true;

    # A high-level setting:
    workspace.clickItemTo = "select";

    # A low-level setting:
    files."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };
}
