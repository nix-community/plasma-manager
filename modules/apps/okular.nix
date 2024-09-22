{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.okular;
  getIndexFromEnum =
    enum: value:
    if value == null then
      null
    else
      lib.lists.findFirstIndex (x: x == value)
        (throw "getIndexFromEnum (okular): Value ${value} isn't present in the enum. This is a bug.")
        enum;
in
with lib.types;
{
  options.programs.okular = {
    enable = lib.mkEnableOption ''
      Enable configuration management for okular.
    '';

    package =
      lib.mkPackageOption pkgs
        [
          "kdePackages"
          "okular"
        ]
        {
          example = "pkgs.libsForQt5.okular";
          extraDescription = ''
            Which okular package to install. Use `pkgs.libsForQt5.okular` in Plasma5 and
            `pkgs.kdePackages.okular` in Plasma6.
          '';
        };

    # ==================================
    #     GENERAL
    general = {
      smoothScrolling = lib.mkOption {
        description = "Use smooth scrolling.";
        default = null;
        type = nullOr bool;
      };

      showScrollbars = lib.mkOption {
        description = "Show scrollbars.";
        default = null;
        type = nullOr bool;
      };

      openFileInTabs = lib.mkOption {
        description = "Open files in tabs.";
        default = null;
        type = nullOr bool;
      };

      viewContinuous = lib.mkOption {
        description = "Open in continous mode by default.";
        default = null;
        type = nullOr bool;
      };

      viewMode = lib.mkOption {
        description = "The view mode for the pages.";
        default = null;
        type = nullOr (enum [
          "Single"
          "Facing"
          "FacingFirstCentered"
          "Summary"
        ]);
      };

      zoomMode =
        let
          enumVals = [
            "100%"
            "fitWidth"
            "fitPage"
            "autoFit"
          ];
        in
        lib.mkOption {
          description = ''
            Specifies the default zoom mode for file which were never opened before.
            For those files which were opened before the previous zoom mode is applied.
          '';
          default = null;
          type = nullOr (enum enumVals);
          apply = getIndexFromEnum enumVals;
        };

      obeyDrm = lib.mkOption {
        description = ''
          Whether Okular should obey DRM (Digital Rights Management) restrictions.
          DRM limitations are used to make it impossible to perform certain actions with PDF documents, such as copying content to the clipboard.
          Note that in some configurations of Okular, this option is not available.
        '';
        default = null;
        type = nullOr bool;
      };

      mouseMode = lib.mkOption {
        description = ''
          Changes what the mouse does.
          See https://docs.kde.org/stable5/en/okular/okular/menutools.html for
          the full description.
          Browse - Click-and-drag with left mouse button.
          Zoom - Zoom in with left mouse button. Reset zoom with right mouse button.
          Rectangle Selection - Draw area selection with left mouse button. Display options with right mouse button.
          Text Selection - Select text with left mouse button. Display options with right mouse button.
          Table Selection - Similar to text selection but allows for transforming the document into a table.
          Magnifier - Activates the magnifier with left mouse button.
        '';
        default = null;
        type = nullOr (enum [
          "Browse"
          "Zoom"
          "RectSelect"
          "TextSelect"
          "TableSelect"
          "Magnifier"
          "TrimSelect"
        ]);
      };
    };

    # ==================================
    #     ACCESSIBILITY
    accessibility = {
      highlightLinks = lib.mkOption {
        description = "Draw borders around links.";
        default = null;
        type = nullOr bool;
      };

      changeColors = {
        enable = lib.mkEnableOption "Whether to change the colors of the documents.";
        mode = lib.mkOption {
          description = "Mode used to change the colors.";
          default = null;
          type = nullOr (enum [
            "Inverted"
            "Paper"
            "Recolor"
          ]);
        };
        paperColor = lib.mkOption {
          description = "Paper color in RGB. Used for the `Paper` mode.";
          default = null;
          example = "255,255,255";
          type = nullOr str;
        };
        recolorBackground = lib.mkOption {
          description = "New background color in RGB. Used for the `Recolor` mode.";
          default = null;
          example = "0,0,0";
          type = nullOr str;
        };
        recolorForeground = lib.mkOption {
          description = "New foreground color in RGB. Used for the `Recolor` mode.";
          default = null;
          example = "255,255,255";
          type = nullOr str;
        };
      };
    };

    # ==================================
    #     PERFORMANCE
    performance = {
      enableTransparencyEffects = lib.mkOption {
        description = "Enable transparancey effects. This may increase CPU usage.";
        default = null;
        type = nullOr bool;
      };

      memoryUsage = lib.mkOption {
        description = "Memory usage of Okular. This impacts the speed performance of Okular as it determines how much computation results are kept in memory and not recomputed.";
        default = null;
        type = nullOr (enum [
          "Low"
          "Normal"
          "Agressive"
          "Greedy"
        ]);
      };
    };
  };

  config = {
    home.packages = lib.mkIf (cfg.enable) [ cfg.package ];
  };

  # ==================================
  #     WRITING THE OKULARPARTRC
  config.programs.plasma.configFile."okularpartrc" = lib.mkIf cfg.enable (
    let
      gen = cfg.general;
      acc = cfg.accessibility;
      perf = cfg.performance;
      applyIfSet = opt: lib.mkIf (opt != null) opt;
    in
    {
      "PageView" = {
        "SmoothScrolling" = applyIfSet gen.smoothScrolling;
        "ShowScrollBars" = applyIfSet gen.showScrollbars;
        "ViewContinuous" = applyIfSet gen.viewContinuous;
        "ViewMode" = applyIfSet gen.viewMode;
        "MouseMode" = applyIfSet gen.mouseMode;
      };

      "Zoom" = {
        "ZoomMode" = applyIfSet gen.zoomMode;
      };
      "Core General" = {
        "ObeyDRM" = applyIfSet gen.obeyDrm;
      };

      "General" = {
        "ShellOpenFileInTabs" = applyIfSet gen.openFileInTabs;
      };

      "Document" = {
        "ChangeColors" = applyIfSet acc.changeColors.enable;
        "RenderMode" = applyIfSet acc.changeColors.mode;
        "PaperColor" = applyIfSet acc.changeColors.paperColor;
      };

      "Dlg Accessibility" = {
        "HighlightLinks" = applyIfSet acc.highlightLinks;
        "RecolorBackground" = applyIfSet acc.changeColors.recolorBackground;
        "RecolorForeground" = applyIfSet acc.changeColors.recolorForeground;
      };

      "Core Performance" = {
        "MemoryLevel" = applyIfSet perf.memoryUsage;
      };

      "Dlg Performance" = {
        "EnableCompositing" = applyIfSet perf.enableTransparencyEffects;
      };
    }
  );
}
