{ config, lib, ... }:

with lib;

let
  cfg = config.programs.konsole;
  profilesSubmodule = {
    options = {
      name = mkOption {
        type = types.str;
        default = null;
        description = ''
          Name of the profile that will be shown in Konsole
        '';
      };
      colorScheme = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "Catppuccin-Mocha";
        description = ''
          Color scheme the profile will use. You can check the files you can
          use in ~/.local/share/konsole or /run/current-system/share/konsole
        '';
      };
    };
  };
in

{
  options.programs.konsole = {
    enable = mkEnableOption ''
      Enable configuration management for Konsole
    '';
    
    defaultProfile = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "Catppuccin";
      description = ''
        The name of the konsole profile file to use by default
        To see what options you have, just take a look at ~/.local/share/konsole/
      '';
    };

    profiles = mkOption {
      type = with types; nullOr (attrsOf (submodule profilesSubmodule));
      default = {};
      description = ''
        Plasma profiles to generate
      '';
    };
  };

  config = mkIf (config.programs.plasma.enable && cfg.enable) {
    programs.plasma.configFile."konsolerc" = mkMerge [
      (
        mkIf (cfg.defaultProfile != null ) {
          "Desktop entry"."DefaultProfile" = cfg.defaultProfile;
        }
      )
    ];

    # Konsole is fine with using symlinked profiles so I'll use the home-manager way
    programs.plasma.dataFile = mkIf (cfg.profiles != {}) (
      mkMerge ([
        (
          mkMerge (
            mapAttrsToList (
              name: profile: {
                "konsole/${name}.profile" = {
                  "General" = {
                    "Name" = profile.name;
                    # Konsole generated profiles seem to allways have this
                    "Parent" = "FALLBACK/";
                  };
                  "Appearance" = {
                    "ColorScheme" = profile.colorScheme;
                  };
                };
              }
            ) cfg.profiles
          )
        )
      ])
    );
  };
}
