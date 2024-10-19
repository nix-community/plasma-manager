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

  capitalizeWord =
    word:
    with lib.strings;
    if word == null then
      null
    else
      concatImapStrings (pos: char: if pos == 1 then toUpper char else char) (stringToCharacters word);
in
{
  pager = {
    description = "The desktop pager is a plasma widget that helps you to organize virtual desktops.";

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
      general = {
        showWindowOutlines = mkBoolOption "Whether to show window outlines";
        showApplicationIconsOnWindowOutlines = mkBoolOption "Whether to show application icons on window outlines";
        showOnlyCurrentScreen = mkBoolOption "Whether to limit the Pager to the set of windows and the geometry of the screen the widget resides on";
        navigationWrapsAround = mkBoolOption "Whether to wrap around when navigating the desktops";
        displayedText =
          let
            options = {
              none = "None";
              desktopNumber = "Number";
              desktopName = "Name";
            };
          in
          lib.mkOption {
            type = with lib.types; nullOr (enum (builtins.attrNames options));
            default = null;
            example = "desktopNumber";
            description = "The text to show inside the desktop rectangles";
            apply = option: if option == null then null else options.${option};
          };
        selectingCurrentVirtualDesktop = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "doNothing"
              "showDesktop"
            ]);
          default = null;
          example = "showDesktop";
          description = "What to do on left-mouse click on a desktop rectangle";
          apply = capitalizeWord;
        };
      };
      settings = lib.mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            showWindowOutlines = true;
          };
        };
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      { general, settings, ... }:
      {
        name = "org.kde.plasma.pager";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) {
            showWindowOutlines = general.showWindowOutlines;
            showWindowIcons = general.showApplicationIconsOnWindowOutlines;
            showOnlyCurrentScreen = general.showOnlyCurrentScreen;
            wrapPage = general.navigationWrapsAround;
            displayedText = general.displayedText;
            currentDesktopSelected = general.selectingCurrentVirtualDesktop;
          };
        } settings;
      };
  };
}
