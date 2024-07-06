{ lib, widgets, ...}:
let
  inherit (lib) mkOption types;
  inherit (widgets.lib) mkBoolOption mkEnumOption;

  convertSidebarPosition = sidebarPosition: let
    mappings = { "left" = "false"; "right" = "true"; };
  in mappings.${sidebarPosition} or (throw "Invalid sidebar position: ${sidebarPosition}");
in
{
  kickoff = {
    description = "Kickoff is the default application launcher of the Plasma desktop.";
    
    opts = {
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "start-here-kde-symbolic";
        description = "The icon to use for the kickoff button.";
      };
      label = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Menu";
        description = "The label to use for the kickoff button.";
      };
      sortAlphabetically = mkBoolOption "Whether to sort menu contents alphabetically or use manual/system sort order.";
      compactDisplayStyle = mkBoolOption "Whether to use a compact display style for list items.";
      sidebarPosition = mkOption {
        type = types.enum [ "left" "right" ];
        default = "left";
        example = "right";
        description = "The position of the sidebar.";
        apply = convertSidebarPosition;
      };
      favoritesDisplayMode = mkEnumOption [ "grid" "list" ] // {
        example = "list";
        description = "How to display favorites.";
      };
      applicationsDisplayMode = mkEnumOption [ "grid" "list" ] // {
        example = "grid";
        description = "How to display applications.";
      };
      showButtonsFor = mkEnumOption [ "power" "session" "custom" "powerAndSession" ] // {
        example = "powerAndSession";
        description = "Which actions should be displayed in the footer.";
      };
      showActionButtonCaptions = mkBoolOption "Whether to display captions ('shut down', 'log out', etc.) for the footer action buttons";
      pin = mkBoolOption "Whether the popup should remain open when another window is activated.";
    };
    convert =
      { icon
      , label
      , sortAlphabetically
      , compactDisplayStyle
      , sidebarPosition
      , favoritesDisplayMode
      , applicationsDisplayMode
      , showButtonsFor
      , showActionButtonCaptions
      , pin
      }: {
        name = "org.kde.plasma.kickoff";
        config.General = lib.filterAttrs (_: v: v != null) (
          {
            icon = icon;
            menuLabel = label;
            alphaSort = sortAlphabetically;
            compactMode = compactDisplayStyle;
            paneSwap = sidebarPosition;
            favoritesDisplay = favoritesDisplayMode;
            applicationsDisplay = applicationsDisplayMode;
            primaryActions = showButtonsFor;
            showActionButtonCaptions = showActionButtonCaptions;
            
            # Other useful options
            pin = pin;
          }
        );
      };
  };
}