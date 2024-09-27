{ config, lib, ... }:

let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.spectacle.shortcuts = {
    captureActiveWindow = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Print";
      description = ''
        The shortcut for capturing the active window.
      '';
    };

    captureCurrentMonitor = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Print";
      description = ''
        The shortcut for capturing the current monitor.
      '';
    };

    captureEntireDesktop = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Shift+Print";
      description = ''
        The shortcut for capturing the entire desktop.
      '';
    };

    captureRectangularRegion = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Shift+S";
      description = ''
        The shortcut for capturing a rectangular region.
      '';
    };

    captureWindowUnderCursor = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Ctrl+Print";
      description = ''
        The shortcut for capturing the window under the cursor.
      '';
    };

    launch = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+S";
      description = ''
        The shortcut for launching Spectacle.
      '';
    };

    launchWithoutCapturing = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Alt+S";
      description = ''
        The shortcut for launching Spectacle without capturing.
      '';
    };

    recordRegion = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Shift+R";
      description = ''
        The shortcut for recording a region on the screen.
      '';
    };

    recordScreen = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Alt+R";
      description = ''
        The shortcut for selecting a screen to record.
      '';
    };

    recordWindow = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          (listOf str)
          str
        ]);
      default = null;
      example = "Meta+Ctrl+R";
      description = ''
        The shortcut for selecting a window to record.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.shortcuts."org.kde.spectacle.desktop" = lib.mkMerge [
      (lib.mkIf (cfg.spectacle.shortcuts.captureActiveWindow != null) {
        ActiveWindowScreenShot = cfg.spectacle.shortcuts.captureActiveWindow;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.captureCurrentMonitor != null) {
        CurrentMonitorScreenShot = cfg.spectacle.shortcuts.captureCurrentMonitor;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.captureEntireDesktop != null) {
        FullScreenScreenShot = cfg.spectacle.shortcuts.captureEntireDesktop;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.captureRectangularRegion != null) {
        RectangularRegionScreenShot = cfg.spectacle.shortcuts.captureRectangularRegion;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.captureWindowUnderCursor != null) {
        WindowUnderCursorScreenShot = cfg.spectacle.shortcuts.captureWindowUnderCursor;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.launch != null) { _launch = cfg.spectacle.shortcuts.launch; })
      (lib.mkIf (cfg.spectacle.shortcuts.launchWithoutCapturing != null) {
        OpenWithoutScreenshot = cfg.spectacle.shortcuts.launchWithoutCapturing;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.recordRegion != null) {
        RecordRegion = cfg.spectacle.shortcuts.recordRegion;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.recordScreen != null) {
        RecordScreen = cfg.spectacle.shortcuts.recordScreen;
      })
      (lib.mkIf (cfg.spectacle.shortcuts.recordWindow != null) {
        RecordWindow = cfg.spectacle.shortcuts.recordWindow;
      })
    ];
  };
}
