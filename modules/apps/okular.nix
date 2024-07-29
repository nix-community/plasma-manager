{ config, lib, pkgs, ... }:

let
  cfg = config.programs.okular;
in with lib.types;
{
  options.programs.okular = {
    enable = lib.mkEnableOption ''
      Enable configuration management for okular.
    '';

    package = lib.mkPackageOption pkgs [ "kdePackages" "okular" ] {
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
        default = "Single";
        type =
          nullOr (enum [ "Single" "Facing" "FacingFirstCentered" "Summary" ]);
      };

      zoomMode = lib.mkOption {
        description = ''
          Specifies the default zoom mode for file which were never opened before. For those files which were opened before the previous zoom mode is applied.
          0: "100%"
          1: "Fit Width"
          2: "Fit Page"
          3: "Auto Fit"
          '';
        default = 1;
        type = nullOr (enum [ 0 1 2 3 ]);
      };

      obeyDrm = lib.mkOption {
        description =
          "Whether Okular should obey DRM (Digital Rights Management) restrictions. DRM limitations are used to make it impossible to perform certain actions with PDF documents, such as copying content to the clipboard. Note that in some configurations of Okular, this option is not available.";
        default = true;
        type = nullOr bool;
      };

      mouseMode = lib.mkOption {
        description = ''
          Browse - The mouse will have its normal behavior, left mouse button for dragging the document and following links and right mouse button for adding bookmarks and fit to width.
          Zoom - The mouse will work as a zoom tool. Clicking left mouse button and dragging will zoom the view to the selected area, clicking right mouse button will bring the document back to the previous zoom.
          Area Selection - The mouse will work as a rectangular region selection tool. In that mode clicking left mouse button and dragging will draw a selection box and provide the option of copying the selected content to the clipboard, speaking the selected text, or transforming the selection region into an image and saving it to a file.
          Text Selection - The mouse will work as a text selection tool. In that mode clicking left mouse button and dragging will give the option of selecting the text of the document. Then, just click with the right mouse button to copy to the clipboard or speak the current selection.
          Table Selection - Draw a rectangle around the text for the table, then click with the left mouse button to divide the text block into rows and columns. A left mouse button click on an existing line removes it and merges the adjacent rows or columns. Finally, just click with the right mouse button to copy the table to the clipboard.
          Magnifier - Activates the magnifier mode for the mouse pointer. Press and hold the left mouse button to activate magnifier widget, move the pointer for panning through the document. The magnifier scales each pixel in the document into 10 pixels in the magnifier widget.
        '';
        default = "Browse";
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
          type = nullOr (enum [ "Inverted" "Paper" "Recolor" ]);
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
        type = nullOr (enum [ "Low" "Normal" "Agressive" "Greedy" ]);
      };
    };
  };

  config = {
    home.packages = lib.mkIf (cfg.enable) [ cfg.package ];
  };

  # ==================================
  #     WRITING THE OKULARPARTRC
  config.programs.plasma.configFile."okularpartrc" = lib.mkIf cfg.enable
  (let
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

    "Zoom" = { "ZoomMode" = applyIfSet gen.zoomMode; };
    "Core General" = { "ObeyDRM" = applyIfSet gen.obeyDrm; };

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
  });
}
