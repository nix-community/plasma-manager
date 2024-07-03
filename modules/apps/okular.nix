{ config, lib, pkgs, ... }:

let
  cfg = config.programs.okular;
in
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
        default = true;
        type = lib.types.bool;
      };

      showScrollbars = lib.mkOption {
        description = "Show scrollbars.";
        default = true;
        type = lib.types.bool;
      };

      openFileInTabs = lib.mkOption {
        description = "Open files in tabs.";
        default = false;
        type = lib.types.bool;
      };

      viewContinuous = lib.mkOption {
        description = "Open in continous mode by default.";
        default = true;
        type = lib.types.bool;
      };
    };

    # ==================================
    #     ACCESSIBILITY
    accessibility = {
      highlightLinks = lib.mkOption {
        description = "Draw borders around links.";
        default = false;
        type = lib.types.bool;
      };

      changeColors = {
        enable = lib.mkEnableOption "Whether to change the colors of the documents.";
        mode = lib.mkOption {
          description = "Mode used to change the colors.";
          default = "Inverted";
          type = lib.types.enum [ "Inverted" "Paper" "Recolor" ];
        };
        paperColor = lib.mkOption {
          description = "Paper color in RGB. Used for the `Paper` mode.";
          default = "255,255,255";
          type = lib.types.str;
        };
        recolorBackground = lib.mkOption {
          description = "New background color in RGB. Used for the `Recolor` mode.";
          default = "255,255,255";
          type = lib.types.str;
        };
        recolorForeground = lib.mkOption {
          description = "New foreground color in RGB. Used for the `Recolor` mode.";
          default = "0,0,0";
          type = lib.types.str;
        };
      };
    };

    # ==================================
    #     PERFORMANCE
    performance = {
      enableTransparencyEffects = lib.mkOption {
        description = "Enable transparancey effects. This may increase CPU usage.";
        default = true;
        type = lib.types.bool;
      };

      memoryUsage = lib.mkOption {
        description = "Memory usage of Okular. This impacts the speed performance of Okular as it determines how much computation results are kept in memory and not recomputed.";
        default = "Normal";
        type = lib.types.enum [ "Low" "Normal" "Agressive" "Greedy" ];
      };
    };
  };

  config = {
    home.packages = lib.mkIf (cfg.enable && cfg.package != null) [ cfg.package ];
  };

  # ==================================
  #     WRITING THE OKULARPARTRC
  config.programs.plasma.configFile."okularpartrc" = lib.mkIf cfg.enable {
    "PageView" = {
      "SmoothScrolling" = cfg.general.smoothScrolling;
      "ShowScrollBars" = cfg.general.showScrollbars;
      "ViewContinuous" = cfg.general.viewContinuous;
    };

    "General" = {
      "ShellOpenFileInTabs" = cfg.general.openFileInTabs;
    };

    "Document" = {
      "ChangeColors" = cfg.accessibility.changeColors.enable;
      "RenderMode" = cfg.accessibility.changeColors.mode;
      "PaperColor" = cfg.accessibility.changeColors.paperColor;
    };

    "Dlg Accessibility" = {
      "HighlightLinks" = cfg.accessibility.highlightLinks;
      "RecolorBackground" = cfg.accessibility.changeColors.recolorBackground;
      "RecolorForeground" = cfg.accessibility.changeColors.recolorForeground;
    };

    "Core Performance" = {
      "MemoryLevel" = cfg.performance.memoryUsage;
    };
    
    "Dlg Performance" = {
      "EnableCompositing" = cfg.performance.enableTransparencyEffects;
    };
  };
}
