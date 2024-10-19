{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.elisa;

  capitalizeWord =
    word:
    if word == null then
      null
    else
      lib.concatImapStrings (pos: char: if pos == 1 then lib.toUpper char else char) (
        lib.stringToCharacters word
      );
in
{
  options.programs.elisa = {
    enable = lib.mkEnableOption "the configuration module for Elisa, KDE's music player";
    package =
      lib.mkPackageOption pkgs
        [
          "kdePackages"
          "elisa"
        ]
        {
          nullable = true;
          example = "pkgs.libsForQt5.elisa";
          extraDescription = ''
            Use `pkgs.libsForQt5.elisa` for Plasma 5 or `pkgs.kdePackages.elisa` for Plasma 6.
            You can also set this to `null` if you're using a system-wide installation of Elisa on NixOS.
          '';
        };

    appearance = {
      colorScheme = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Krita dark orange";
        description = ''
          The colour scheme of the UI. Leave this setting at `null` in order to
          not override the systems default scheme for for this application.
        '';
      };
      showNowPlayingBackground = lib.mkOption {
        description = ''
          Set to `true` in order to use a blurred version of the album artwork as the background for the 'Now Playing' section in Elisa.
          Set to `false` in order to use a solid colour inherited from the Plasma theme.
        '';
        default = null;
        type = lib.types.nullOr lib.types.bool;
      };
      showProgressOnTaskBar = lib.mkOption {
        description = ''
          Whether to present the current track progress in the task manager widgets in panels.
        '';
        default = null;
        type = lib.types.nullOr lib.types.bool;
      };
      embeddedView = lib.mkOption {
        description = ''
          Select the sidebar-embedded view for Elisa. The selected view will
          be omitted from the sidebar, and its contents will instead be individually
          displayed after the main view buttons.
        '';
        default = null;
        type = lib.types.nullOr (
          lib.types.enum [
            "albums"
            "artists"
            "genres"
          ]
        );
        apply = capitalizeWord;
      };
      defaultView = lib.mkOption {
        description = ''
          The default view which will be opened when Elisa is started.
        '';
        default = null;
        type = lib.types.nullOr (
          lib.types.enum [
            "nowPlaying"
            "recentlyPlayed"
            "frequentlyPlayed"
            "allAlbums"
            "allArtists"
            "allTracks"
            "allGenres"
            "files"
            "radios"
          ]
        );
        apply = capitalizeWord;
      };
      defaultFilesViewPath = lib.mkOption {
        description = ''
          The default path which will be opened in the Files view.
          Unlike the index paths, shell variables cannot be used here.
        '';
        default = null;
        example = "/home/username/Music";
        type = lib.types.nullOr lib.types.str;
      };
    };

    indexer = {
      paths = lib.mkOption {
        description = ''
          Stateful, persistent paths to be indexed by the Elisa Indexer.
          The Indexer will recursively search for valid music files along the given paths.
          Shell variables, such as `$HOME`, may be used freely.
        '';
        default = null;
        example = ''
          [
            "$HOME/Music"
            "/ExternalDisk/more-music"
          ]
        '';
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
      };
      scanAtStartup = lib.mkOption {
        description = "Whether to automatically scan the configured index paths for new tracks when Elisa is started.";
        default = null;
        example = true;
        type = lib.types.nullOr lib.types.bool;
      };
      ratingsStyle = lib.mkOption {
        description = ''
          The Elisa music database can attach user-defined ratings to each track.
          This option defines if the rating is a `0-5 stars` rating, or a binary `Favourite/Not Favourite` rating.
        '';
        default = null;
        type = lib.types.nullOr (
          lib.types.enum [
            "stars"
            "favourites"
          ]
        );
      };
    };

    player = {
      playAtStartup = lib.mkOption {
        description = "Whether to automatically play the previous track when Elisa is started.";
        default = null;
        type = lib.types.nullOr lib.types.bool;
      };
      minimiseToSystemTray = lib.mkOption {
        description = ''
          Set to `true` in order to make Elisa continue playing in the System Tray after being closed.
          Set to `false` in order to make Elisa quit after being closed.

          By default, the system tray icon is the symbolic variant of the Elisa icon.
        '';
        default = null;
        type = lib.types.nullOr lib.types.bool;
      };
      useAbsolutePlaylistPaths = lib.mkOption {
        description = ''
          Set to `true` in order to make Elisa write `.m3u8` playlist files using the absolute paths to each track.
          Setting to `false` will make Elisa intelligently pick between relative or absolute paths.
        '';
        default = null;
        type = lib.types.nullOr lib.types.bool;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
    programs.plasma.configFile."elisarc" =
      let
        concatenatedPaths = builtins.concatStringsSep "," cfg.indexer.paths;
      in
      lib.mkMerge [
        (lib.mkIf (cfg.indexer.paths != null) {
          ElisaFileIndexer.RootPath = {
            shellExpand = true;
            value = concatenatedPaths;
          };
        })
        (lib.mkMerge [
          (lib.mkIf (cfg.player.playAtStartup != null) {
            PlayerSettings.PlayAtStartup.value = cfg.player.playAtStartup;
          })
          (lib.mkIf (cfg.indexer.scanAtStartup != null) {
            PlayerSettings.ScanAtStartup.value = cfg.indexer.scanAtStartup;
          })
          (lib.mkIf (cfg.appearance.showNowPlayingBackground != null) {
            PlayerSettings.ShowNowPlayingBackground.value = cfg.appearance.showNowPlayingBackground;
          })
          (lib.mkIf (cfg.appearance.showProgressOnTaskBar != null) {
            PlayerSettings.ShowProgressOnTaskBar.value = cfg.appearance.showProgressOnTaskBar;
          })
          (lib.mkIf (cfg.player.minimiseToSystemTray != null) {
            PlayerSettings.ShowSystemTrayIcon.value = cfg.player.minimiseToSystemTray;
          })
          (lib.mkIf (cfg.indexer.ratingsStyle != null) {
            PlayerSettings.UseFavoriteStyleRatings.value =
              if (cfg.indexer.ratingsStyle == "Stars") then false else true;
          })
        ])
        (lib.mkIf (cfg.player.useAbsolutePlaylistPaths != null) {
          Playlist.AlwaysUseAbsolutePlaylistPaths.value = cfg.player.useAbsolutePlaylistPaths;
        })
        (lib.mkIf (cfg.appearance.colorScheme != null) {
          UiSettings.ColorScheme.value = cfg.appearance.colorScheme;
        })
        (lib.mkMerge [
          (lib.mkIf (cfg.appearance.embeddedView != null) {
            Views.EmbeddedView.value = "All" + cfg.appearance.embeddedView;
          })
          (lib.mkIf (cfg.appearance.defaultFilesViewPath != null) {
            Views.InitialFilesViewPath.value = cfg.appearance.defaultFilesViewPath;
          })
          (lib.mkIf (cfg.appearance.defaultView != null) {
            Views.InitialView.value = cfg.appearance.defaultView;
          })
        ])
      ];
  };
}
