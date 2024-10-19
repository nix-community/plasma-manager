{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  mkBoolOption =
    description:
    lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      inherit description;
    };

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (kickoff widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  convertSidebarPosition =
    sidebarPosition:
    let
      mappings = {
        left = false;
        right = true;
      };
    in
    if sidebarPosition == null then
      null
    else
      mappings.${sidebarPosition} or (throw "Invalid sidebar position: ${sidebarPosition}");
in
{
  kickoff = {
    description = "Kickoff is the default application launcher of the Plasma desktop.";

    opts = {
      position = lib.mkOption {
        type = positionType;
        example = {
          horizontal = 250;
          vertical = 50;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = lib.mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 500;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      icon = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "start-here-kde-symbolic";
        description = ''
          The icon to use for the kickoff button.

          This can also be used to specify a custom image for the kickoff button.
          To do this, set the value to a absolute path to the image file.
        '';
      };
      label = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "Menu";
        description = "The label to use for the kickoff button.";
      };
      sortAlphabetically = mkBoolOption "Whether to sort menu contents alphabetically or use manual/system sort order.";
      compactDisplayStyle = mkBoolOption "Whether to use a compact display style for list items.";
      sidebarPosition = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "left"
            "right"
          ]);
        default = null;
        example = "left";
        description = "The position of the sidebar.";
        apply = convertSidebarPosition;
      };
      favoritesDisplayMode =
        let
          enumVals = [
            "grid"
            "list"
          ];
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum enumVals);
          default = null;
          example = "list";
          description = "How to display favorites.";
          apply = getIndexFromEnum enumVals;
        };
      applicationsDisplayMode =
        let
          enumVals = [
            "grid"
            "list"
          ];
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum enumVals);
          default = null;
          example = "grid";
          description = "How to display applications.";
          apply = getIndexFromEnum enumVals;
        };
      showButtonsFor =
        let
          enumVals = [
            "power"
            "session"
            "powerAndSession"
          ];
          buttonsEnum = [
            "lock-screen"
            "logout"
            "save-session"
            "switch-user"
            "suspend"
            "hibernate"
            "reboot"
            "shutdown"
          ];
        in
        lib.mkOption {
          type =
            with lib.types;
            nullOr (
              either (enum enumVals) (submodule {
                options.custom = lib.mkOption {
                  type = listOf (enum buttonsEnum);
                  example = [
                    "shutdown"
                    "reboot"
                  ];
                  description = "The custom buttons to show";
                };
              })
            );
          default = null;
          example = {
            custom = [
              "shutdown"
              "reboot"
              "logout"
            ];
          };
          description = "Which actions should be displayed in the footer.";
          apply =
            value:
            if value == null then
              { }
            else if value ? custom then
              {
                primaryActions = 2;
                systemFavorites = builtins.concatStringsSep ''\\,'' value.custom;
              }
            else
              {
                primaryActions =
                  builtins.elemAt
                    [
                      0
                      1
                      3
                    ]
                    (
                      lib.lists.findFirstIndex (
                        x: x == value
                      ) (throw "kickoff: non-existent value ${value}! This is a bug!") enumVals
                    );
                systemFavorites =
                  if value == "session" then
                    builtins.concatStringsSep ''\\,'' (
                      builtins.filter (v: v != null) (lib.imap0 (i: v: if i < 4 then v else null) buttonsEnum)
                    )
                  else if value == "power" then
                    builtins.concatStringsSep ''\\,'' (
                      builtins.filter (v: v != null) (lib.imap0 (i: v: if i > 3 then v else null) buttonsEnum)
                    )
                  else
                    builtins.concatStringsSep ''\\,'' buttonsEnum;
              };
        };
      showActionButtonCaptions = mkBoolOption "Whether to display captions ('shut down', 'log out', etc.) for the footer action buttons";
      pin = mkBoolOption "Whether the popup should remain open when another window is activated.";
      popupHeight = lib.mkOption {
        type = with lib.types; nullOr ints.positive;
        default = null;
        example = 500;
      };
      popupWidth = lib.mkOption {
        type = with lib.types; nullOr ints.positive;
        default = null;
        example = 700;
      };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            icon = "nix-snowflake-white";
          };
          popupHeight = 500;
        };
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        icon,
        label,
        sortAlphabetically,
        compactDisplayStyle,
        sidebarPosition,
        favoritesDisplayMode,
        applicationsDisplayMode,
        showButtonsFor,
        showActionButtonCaptions,
        pin,
        popupHeight,
        popupWidth,
        settings,
        ...
      }:
      {
        name = "org.kde.plasma.kickoff";
        config = lib.recursiveUpdate (lib.filterAttrsRecursive (_: v: v != null) {
          popupHeight = popupHeight;
          popupWidth = popupWidth;

          General = {
            inherit icon pin showActionButtonCaptions;

            menuLabel = label;
            alphaSort = sortAlphabetically;
            compactMode = compactDisplayStyle;
            paneSwap = sidebarPosition;
            favoritesDisplay = favoritesDisplayMode;
            applicationsDisplay = applicationsDisplayMode;
          } // showButtonsFor;
        }) settings;
      };
  };
}
