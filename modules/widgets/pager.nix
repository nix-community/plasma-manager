{ lib, ... }:

let
  inherit (lib) mkOption types;
  inherit (import ./lib.nix { inherit lib; }) configValueType;
  inherit (import ./default.nix { inherit lib; }) positionType sizeType;

  mkBoolOption =
    description:
    mkOption {
      type = with types; nullOr bool;
      default = null;
      inherit description;
    };
in
{
  pager = {
    description = "The desktop pager is a plasma widget that helps you to organize virtual desktops.";
    opts = {
      position = mkOption {
        type = positionType;
        example = {
          horizontal = 250;
          vertical = 50;
        };
        description = "The position of the widget. (Only for desktop widget)";
      };
      size = mkOption {
        type = sizeType;
        example = {
          width = 500;
          height = 500;
        };
        description = "The size of the widget. (Only for desktop widget)";
      };
      behavior = {
        general = {
          showApplicationIconsOnWindowOutlines = mkBoolOption "Show application icons on window outlines.";
          showOnlyCurrentScreen = mkBoolOption "Show only current screen.";
          navigationWrapsAround = mkBoolOption "Navigation wraps around.";
        };
        textDisplay =
          let
            options = {
              noText = null;
              desktopNumber = "Number";
              desktopName = "Name";
            };
          in
          mkOption {
            type = with types; nullOr (enum (builtins.attrNames options));
            default = null;
            example = "desktopNumber";
            description = "Choose what to show inside each virtual desktop representation.";
            apply = option: if (option == null || option == options.noText) then null else options."${option}";
          };
        selectingCurrentVirtualDesktop =
          let
            options = {
              doesNothing = null;
              showsTheDesktop = "ShowDesktop";
            };

          in
          mkOption {
            type = with types; nullOr (enum (builtins.attrNames options));
            default = null;
            example = "showsTheDesktop";
            description = "Choose which action to take when selecting a virtual desktop representation.";
            apply =
              option: if (option == null || option == options.doesNothing) then null else options."${option}";
          };
      };
      settings = mkOption {
        type = configValueType;
        default = null;
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        position,
        size,
        behavior,
        settings,
      }:
      {
        name = "org.kde.plasma.pager";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) {
            showWindowIcons = behavior.general.showApplicationIconsOnWindowOutlines;
            showOnlyCurrentScreen = behavior.general.showOnlyCurrentScreen;
            wrapPage = behavior.general.navigationWrapsAround;
            displayedText = behavior.textDisplay;
            currentDesktopSelected = behavior.selectingCurrentVirtualDesktop;
          };
        } settings;
      };
  };
}
