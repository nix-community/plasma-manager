{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description: mkOption {
    type = with types; nullOr bool;
    default = null;
    inherit description;
  };

  convertSidebarPosition = sidebarPosition:
    let
      mappings = { left = "false"; right = "true"; };
    in
      mappings.${sidebarPosition} or (throw "Invalid sidebar position: ${sidebarPosition}");
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
      favoritesDisplayMode = mkOption {
        type = with types; nullOr (enum [ "grid" "list" ]);
        default = null;
        example = "list";
        description = "How to display favorites.";
      };
      applicationsDisplayMode = mkOption {
        type = with types; nullOr (enum [ "grid" "list" ]);
        default = null;
        example = "grid";
        description = "How to display applications.";
      };
      showButtonsFor = mkOption {
        type = with types; nullOr (enum [ "power" "session" "custom" "powerAndSession" ]);
        default = null;
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
