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
        `pkgs.kdePackages.okular` in Plasma6. Use `null` if home-manager should not install okular
        (use this if you want to manage the settings of this user of a system-wide okular
        installation).
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
    home.packages = lib.mkIf (cfg.enable && cfg.package != null) [ cfg.package ];
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
  });
}
