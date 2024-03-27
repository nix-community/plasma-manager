{ config, lib, pkgs, ... }:
let
  inherit (import ../../lib/types.nix { inherit lib; }) basicSettingsType;

  cfg = config.programs.konsole;
  profilesSubmodule = {
    options = {
      name = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          Name of the profile. Defaults to the attribute name.
        '';
      };
      colorScheme = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "Catppuccin-Mocha";
        description = ''
          Color scheme the profile will use. You can check the files you can
          use in ~/.local/share/konsole or /run/current-system/share/konsole
        '';
      };
      command = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "''${pkgs.zsh}/bin/zsh";
        description = ''
          The command to run on new sessions.
        '';
      };
      font = {
        name = lib.mkOption {
          type = lib.types.str;
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
            Name of the font the profile should use.
          '';
        };
        size = lib.mkOption {
          # The konsole ui gives you a limited range
          type = (lib.types.ints.between 4 128);
          default = 10;
          example = 12;
          description = ''
            Size of the font.
            Needs a font to be set due to konsole limitations.
          '';
        };
      };
    };
  };
in

{
  options.programs.konsole = {
    enable = lib.mkEnableOption ''
      Enable configuration management for Konsole.
    '';

    defaultProfile = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Catppuccin";
      description = ''
        The name of the konsole profile file to use by default.
        To see what options you have, just take a look at ~/.local/share/konsole/
      '';
    };

    profiles = lib.mkOption {
      type = with lib.types; nullOr (attrsOf (submodule profilesSubmodule));
      default = { };
      description = ''
        Plasma profiles to generate.
      '';
    };

    extraConfig = lib.mkOption {
      type = with lib.types; nullOr (attrsOf (attrsOf (basicSettingsType)));
      default = null;
      description = ''
        Extra config to add to konsolerc.
      '';
    };
  };

  config = lib.mkIf (cfg.enable) {
    programs.plasma.configFile."konsolerc" = lib.mkMerge [
      (
        lib.mkIf (cfg.defaultProfile != null) {
          "Desktop Entry"."DefaultProfile".value = cfg.defaultProfile;
        }
      )
      (
        lib.mkIf (cfg.extraConfig != null) (lib.mapAttrs
          (groupName: groupAttrs:
            (lib.mapAttrs (keyName: keyAttrs: { value = keyAttrs; }) groupAttrs))
          cfg.extraConfig)
      )
    ];

    xdg.dataFile = lib.mkIf (cfg.profiles != { })
      (
        lib.mkMerge ([
          (
            lib.mkMerge (
              lib.mapAttrsToList
                (
                  attrName: profile:
                    let
                      # Use the name from the name option if it's set
                      profileName = if builtins.isString profile.name then profile.name else attrName;
                      fontString = lib.mkIf (profile.font.name != null) "${profile.font.name},${builtins.toString profile.font.size}";
                    in
                    {
                      "konsole/${profileName}.profile".text = lib.generators.toINI { } {
                        "General" = (
                          {
                            "Name" = profileName;
                            # Konsole generated profiles seem to always have this
                            "Parent" = "FALLBACK/";
                          } //
                          (lib.optionalAttrs (profile.command != null) { "Command" = profile.command; })
                        );
                        "Appearance" = (
                          {
                            # If the font size is not set we leave a comma a the end after the name
                            # We should fix this probs but konsole doesn't seem to care ¯\_(ツ)_/¯
                            "Font" = fontString.content;
                          } //
                          (lib.optionalAttrs (profile.colorScheme != null) { "ColorScheme" = profile.colorScheme; })
                        );
                      };
                    }
                )
                cfg.profiles
            )
          )
        ])
      );
  };
}
