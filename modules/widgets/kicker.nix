{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description: mkOption {
    type = with types; nullOr bool;
    default = null;
    example = true;
    inherit description;
  };

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (kicker widget): Value ${value} isn't present in the enum. This is a bug")
        enum;
  
  checkPath = path:
    if path == null
    then null
    else
      if lib.strings.hasPrefix "/" path
      then path
      else throw "checkPath (kicker widget): Path ${path} is not an absolute path.";
in
{
  kicker = {
    description = ''
      Kicker is a launcher, which is also known as Application Menu.
      Kicker does not have fancy features, like the other launchers,
      but provides a tightly arranged interface.
    '';

    opts = {
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
        let enumVals = [ "nameOnly" "genericNameOnly" "nameAndGenericName" "genericNameAndName" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "nameOnly";
          description = "The format of the application name to display.";
          apply = getIndexFromEnum enumVals;
        };
      behavior = {
        sortAlphabetically = mkBoolOption "Whether to sort the applications alphabetically.";
        flattenCategories = mkBoolOption "Whether to flatten top-level menu categories to a single level instead of displaying sub-categories.";
        showIconsOnRootLevel = mkBoolOption "Whether to show icons on the root level of the menu.";
      };
      categories = {
        show = {
          recentApplications = mkBoolOption "Whether to show recent applications.";
          recentFiles = mkBoolOption "Whether to show recent files.";
        };
        order =
          let enumVals = [ "recentFirst" "popularFirst" ];
          in mkOption {
            type = with types; nullOr (enum enumVals);
            default = null;
            example = "recentFirst";
            description = "The order in which to show the categories.";
            apply = getIndexFromEnum enumVals;
          };
      };
      search = {
        alignResultsToBottom = mkBoolOption "Whether to align the search results to the bottom of the screen.";
        expandSearchResults = mkBoolOption "Whether to expand the search results to bookmarks, files and emails.";
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
      , customButtonImage
      , applicationNameFormat
      , behavior
      , categories
      , search
      , settings
      }: {
        name = "org.kde.plasma.kicker";
        config = lib.recursiveUpdate {
          General = lib.filterAttrs (_: v: v != null) (
            {
              inherit icon customButtonImage;
              inherit (search) alignResultsToBottom;

              useCustomButtonImage = (customButtonImage != null);

              appNameFormat = applicationNameFormat;

              alphaSort = behavior.sortAlphabetically;
              limitDepth = behavior.flattenCategories;
              showIconsRootLevel = behavior.showIconsOnRootLevel;

              showRecentApps = categories.show.recentApplications;
              showRecentDocs = categories.show.recentFiles;
              recentOrdering = categories.order;

              useExtraRunners = search.expandSearchResults;
            }
          );
        } settings;
      };
  };
}