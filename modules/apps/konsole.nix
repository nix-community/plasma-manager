{ config, lib, ... }:
let
  inherit
    (import ../../lib/types.nix {
      inherit lib;
      inherit config;
    })
    basicSettingsType
    ;

  # used as shown in the example in the library docs:
  # https://noogle.dev/f/lib/attrsets/mapAttrs'
  createColorSchemes = lib.attrsets.mapAttrs' (
    name: value:
    lib.attrsets.nameValuePair "konsole/${name}.colorscheme" {
      enable = true;
      source = value;
    }
  );

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
          use in `$HOME/.local/share/konsole` or `/run/current-system/sw/share/konsole`.
          You might also add a custom color scheme using
          `programs.konsole.customColorSchemes`.
        '';
      };
      command = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = lib.literalExpression ''"''${pkgs.zsh}/bin/zsh"'';
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
            Due to Konsole limitations, only a limited range of sizes is possible.
          '';
        };
      };
      extraConfig = lib.mkOption {
        type = with lib.types; attrsOf (attrsOf basicSettingsType);
        default = { };
        example = { };
        description = ''
          Extra keys to manually add to the profile.
        '';
      };
    };
  };
in

{
  options.programs.konsole = {
    enable = lib.mkEnableOption ''
      Enable configuration management for Konsole, the KDE Terminal.
    '';

    defaultProfile = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Catppuccin";
      description = ''
        The name of the Konsole profile file to use by default.
        To see what options you have, take a look at `$HOME/.local/share/konsole`
      '';
    };

    profiles = lib.mkOption {
      type = with lib.types; nullOr (attrsOf (submodule profilesSubmodule));
      default = { };
      description = ''
        Plasma profiles to generate.
      '';
    };

    customColorSchemes = lib.mkOption {
      type = with lib.types; attrsOf path;
      default = { };
      description = ''
        Custom color schemes to be added to the installation. The attribute key maps to their name.
        Choose them in any profile with `profiles.<profile>.colorScheme = <name>`;
      '';
    };

    ui.colorScheme = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Krita dark orange";
      description = ''
        The color scheme of the UI. Leave this setting at `null` in order to
        not override the system's default scheme for for this application.
      '';
    };

    extraConfig = lib.mkOption {
      type = with lib.types; nullOr (attrsOf (attrsOf basicSettingsType));
      default = null;
      description = ''
        Extra config to add to the `konsolerc`.
      '';
    };
  };

  config = lib.mkIf (cfg.enable) {
    programs.plasma.configFile."konsolerc" = lib.mkMerge [
      (lib.mkIf (cfg.defaultProfile != null) {
        "Desktop Entry"."DefaultProfile" = "${cfg.defaultProfile}.profile";
      })
      (lib.mkIf (cfg.extraConfig != null) (
        lib.mapAttrs (
          groupName: groupAttrs: (lib.mapAttrs (keyName: keyAttrs: { value = keyAttrs; }) groupAttrs)
        ) cfg.extraConfig
      ))
      {
        "UiSettings"."ColorScheme" = lib.mkIf (cfg.ui.colorScheme != null) {
          value = cfg.ui.colorScheme;
          # The key needs to be immutable to work properly when using overrideConfig.
          # See discussion at: https://github.com/nix-community/plasma-manager/pull/186
          immutable = lib.mkIf config.programs.plasma.overrideConfig (lib.mkDefault true);
        };
      }
    ];

    xdg.dataFile = lib.mkMerge [
      (lib.mkIf (cfg.profiles != { }) (
        lib.mkMerge [
          (lib.mkMerge (
            lib.mapAttrsToList (
              attrName: profile:
              let
                # Use the name from the name option if it's set
                profileName = if builtins.isString profile.name then profile.name else attrName;
                fontString = lib.mkIf (
                  profile.font.name != null
                ) "${profile.font.name},${builtins.toString profile.font.size}";
              in
              {
                "konsole/${profileName}.profile".text = lib.generators.toINI { } (
                  lib.recursiveUpdate {
                    "General" = (
                      {
                        "Name" = profileName;
                        # Konsole generated profiles seem to always have this
                        "Parent" = "FALLBACK/";
                      }
                      // (lib.optionalAttrs (profile.command != null) { "Command" = profile.command; })
                    );
                    "Appearance" = (
                      {
                        # If the font size is not set we leave a comma at the end after the name
                        # We should fix this probs but konsole doesn't seem to care ¯\_(ツ)_/¯
                        "Font" = fontString.content;
                      }
                      // (lib.optionalAttrs (profile.colorScheme != null) { "ColorScheme" = profile.colorScheme; })
                    );
                  } profile.extraConfig
                );
              }
            ) cfg.profiles
          ))
        ]
      ))
      (createColorSchemes cfg.customColorSchemes)
    ];
  };
}
