{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description: mkOption {
    type = with types; nullOr bool;
    default = null;
    inherit description;
  };

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (kickoff widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  convertSidebarPosition = sidebarPosition:
    let
      mappings = { left = false; right = true; };
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
        description = ''
          The icon to use for the kickoff button.

          This can also be used to specify a custom image for the kickoff button.
          To do this, set the value to a absolute path to the image file.
        '';
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
      favoritesDisplayMode =
        let enumVals = [ "grid" "list" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "list";
          description = "How to display favorites.";
          apply = getIndexFromEnum enumVals;
        };
      applicationsDisplayMode =
        let enumVals = [ "grid" "list" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "grid";
          description = "How to display applications.";
          apply = getIndexFromEnum enumVals;
        };
      showButtonsFor =
        let enumVals = [ "power" "session" "custom" "powerAndSession" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "powerAndSession";
          description = "Which actions should be displayed in the footer.";
          apply = getIndexFromEnum enumVals;
        };
      showActionButtonCaptions = mkBoolOption "Whether to display captions ('shut down', 'log out', etc.) for the footer action buttons";
      pin = mkBoolOption "Whether the popup should remain open when another window is activated.";
      popupHeight = mkOption {
        type = with types; ints.positive;
        default = null;
        example = 500;
      };
      popupWidth = mkOption {
        type = with types; ints.positive;
        default = null;
        example = 700;
      };
      settings = mkOption {
        type = with types; nullOr (attrsOf (attrsOf (either (oneOf [ bool float int str ]) (listOf (oneOf [ bool float int str ])))));
        default = null;
        example = {
          General = {
            icon = "nix-snowflake-white";
          };
        };
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then {} else settings;
      };
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
      , popupHeight
      , popupWidth
      , settings
      }: {
        name = "org.kde.plasma.kickoff";
        config = lib.recursiveUpdate {
          popupHeight = popupHeight;
          popupWidth = popupWidth;

          General = lib.filterAttrs (_: v: v != null) (
            {
              inherit icon pin;

              menuLabel = label;
              alphaSort = sortAlphabetically;
              compactMode = compactDisplayStyle;
              paneSwap = sidebarPosition;
              favoritesDisplay = favoritesDisplayMode;
              applicationsDisplay = applicationsDisplayMode;
              primaryActions = showButtonsFor;
              showActionButtonCaptions = showActionButtonCaptions;
            }
          );
        } settings;
      };
  };
}
