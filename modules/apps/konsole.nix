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
      command = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "''${pkgs.zsh}/bin/zsh";
        description = ''
          The command to run on new sessions
        '';
      };
      font = {
        name = mkOption {
          type = with types; nullOr str;
          /*
          TODO: Set default to null after adding an assertion
          Konsole needs to have a font set to be able to change font size
          Since I couldn't get that to work I'll just set a default font
          Not ideal since IMO we should only write things that are set explicitly
          by the user but ehh it is what it is
          */
          default = "Hack";
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
                    "Command" = profile.command;
                    "Name" = profileName;
                    # Konsole generated profiles seem to allways have this
                    "Parent" = "FALLBACK/";
                  };
                  "Appearance" = {
                    "ColorScheme" = profile.colorScheme;
                    # If the font size is not set we leave a comma a the end after the name
                    # We should fix this probs but konsole doesn't seem to care ¯\_(ツ)_/¯
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
