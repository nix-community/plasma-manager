{ config, lib, ... }:

with lib;

let
  cfg = config.programs.konsole;
  profilesSubmodule = {
    options = {
      name = mkOption {
        type = with types; nullOr str;
        default = null;
        description = ''
          Name of the profile. Defaults to the attribute name
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
      font = {
        name = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "Hack";
          description = ''
            Name of the font the profile should use
          '';
        };
        size = mkOption {
          # The konsole ui gives you a limited range
          type = with types; nullOr (ints.between 4 128);
          default = null;
          example = 12;
          description = ''
            Size of the font.
            Needs a font to be set due to konsole limitations
          '';
        };
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

    programs.plasma.dataFile = mkIf (cfg.profiles != {}) (
      mkMerge ([
        (
          mkMerge (
            mapAttrsToList (
              attrName: profile:
              let
                # Use the name from the name option if it's set
                profileName = if builtins.isString profile.name then profile.name else attrName;
              in
              {
                "konsole/${profileName}.profile" = {
                  "General" = {
                    "Name" = profileName;
                    # Konsole generated profiles seem to allways have this
                    "Parent" = "FALLBACK/";
                  };
                  "Appearance" = {
                    "ColorScheme" = profile.colorScheme;
                    "Font" = with profile.font; "${name},${builtins.toString size}";
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
