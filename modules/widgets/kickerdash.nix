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
      example = true;
      inherit description;
    };

  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (kickerdash widget): Value ${value} isn't present in the enum. This is a bug")
        enum;

  checkPath =
    path:
    if path == null then
      null
    else if lib.strings.hasPrefix "/" path then
      path
    else
      throw "checkPath (kickerdash widget): Path ${path} is not an absolute path.";
in
{
  kickerdash = {
    description = "Application Dashboard (kickerdash) is an alternative launcher which fills the whole desktop.";

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
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "start-here-kde-symbolic";
        description = "The icon to use for the kickoff button.";
      };
      customButtonImage = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/home/user/pictures/custom-button.png";
        description = "The absolute path image to use for the custom button.";
        apply = checkPath;
      };
      applicationNameFormat =
        let
          enumVals = [
            "nameOnly"
            "genericNameOnly"
            "nameAndGenericName"
            "genericNameAndName"
          ];
        in
        mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "nameOnly";
          description = "The format of the application name to display.";
          apply = getIndexFromEnum enumVals;
        };
      behavior = {
        sortAlphabetically = mkBoolOption "Whether to sort the applications alphabetically.";
      };
      categories = {
        show = {
          recentApplications = mkBoolOption "Whether to show recent applications.";
          recentFiles = mkBoolOption "Whether to show recent files.";
        };
        order =
          let
            enumVals = [
              "recentFirst"
              "popularFirst"
            ];
          in
          mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "recentFirst";
            description = "The order in which to show the categories.";
            apply = getIndexFromEnum enumVals;
          };
      };
      search = {
        expandSearchResults = mkBoolOption "Whether to expand the search results to bookmarks, files and emails.";
      };
      settings = mkOption {
        type = configValueType;
        default = null;
        example = {
          General = {
            icon = "nix-snowflake-white";
          };
        };
        description = "Extra configuration options for the widget.";
        apply = settings: if settings == null then { } else settings;
      };
    };
    convert =
      {
        icon,
        customButtonImage,
        applicationNameFormat,
        behavior,
        categories,
        search,
        settings,
        ...
      }:
      {
        name = "org.kde.plasma.kickerdash";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) {
            inherit icon customButtonImage;
            useCustomButtonImage = (customButtonImage != null);

            appNameFormat = applicationNameFormat;

            alphaSort = behavior.sortAlphabetically;

            showRecentApps = categories.show.recentApplications;
            showRecentDocs = categories.show.recentFiles;
            recentOrdering = categories.order;

            useExtraRunners = search.expandSearchResults;
          };
        } settings;
      };
  };
}
