{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkBoolOption = description: lib.mkOption {
    type = with lib.types; nullOr bool;
    default = null;
    inherit description;
  };

  getIndexFromEnum = enum: value:
    if value == null
    then null
    else
      lib.lists.findFirstIndex
        (x: x == value)
        (throw "getIndexFromEnum (plasmusic-toolbar widget): Value ${value} isn't present in the enum. This is a bug")
        enum;
in
{
  plasmusicToolbar = {
    description = "KDE Plasma widget that shows currently playing song information and provide playback controls.";

    opts = {
      panelIcon = {
        icon = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "view-media-track";
          description = "Icon to show in the panel.";
        };
        albumCover = {
          useAsIcon = mkBoolOption "Whether to use album cover as icon or not.";
          radius = mkOption {
            type = types.nullOr (types.ints.between 0 25);
            default = null;
            example = 8;
            description = "Radius of the album cover icon.";
            apply = builtins.toString;
          };
        };
      };
      preferredSource =
        let enumVals = [ "any" "spotify" "vlc" ];
        in mkOption {
          type = with types; nullOr (enum enumVals);
          default = null;
          example = "any";
          description = "Preferred source for song information.";
          apply = getIndexFromEnum enumVals;
        };
      songText = {
        maximumWidth = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          example = 200;
          description = "Maximum width of the song text.";
          apply = builtins.toString;
        };
        scrolling = {
          behavior =
            let
              enumVals = [ "alwaysScroll" "scrollOnHover" "alwaysScrollExceptOnHover" ];
            in
            mkOption {
              type = with types; nullOr (enum enumVals);
              default = null;
              example = "alwaysScroll";
              description = "Scrolling behavior of the song text.";
              apply = getIndexFromEnum enumVals;
            };
          speed = mkOption {
            type = types.nullOr (types.ints.between 1 10);
            default = null;
            example = 3;
            description = "Speed of the scrolling text.";
            apply = builtins.toString;
          };
        };
        displayInSeparateLines = mkBoolOption "Whether to display song information (title and artist) in separate lines or not.";
      };
      showPlaybackControls = mkBoolOption "Whether to show playback controls or not.";
    };
    convert =
      { panelIcon
      , preferredSource
      , songText
      , showPlaybackControls
      }: {
        name = "plasmusic-toolbar";
        config.General = lib.filterAttrs (_: v: v != null) (
          {
            panelIcon = panelIcon.icon;
            useAlbumCoverAsPanelIcon = panelIcon.albumCover.useAsIcon;
            albumCoverRadius = panelIcon.albumCover.radius;

            sourceIndex = preferredSource;

            maxSongWidthInPanel = songText.maximumWidth;
            textScrollingSpeed = songText.scrolling.speed;
            separateText = songText.displayInSeparateLines;
            textScrollingBehaviour = songText.scrolling.behavior;

            commandsInPanel = showPlaybackControls;
          }
        );
      };
  };
}
