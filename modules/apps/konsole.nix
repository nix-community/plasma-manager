{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../lib/types.nix { inherit config lib; }) basicSettingsType;

  iniFormat = pkgs.formats.ini { };

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
          example = "Hack";
          description = ''
            Name of the font the profile should use.
          '';
        };
        size = lib.mkOption {
          # The konsole ui gives you a limited range
          type = (lib.types.numbers.between 4 128);
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
      configuration management for Konsole, the KDE Terminal.
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
      type =
        with lib.types;
        attrsOf (oneOf [
          path
          iniFormat.type
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          CustomTheme = ./CustomTheme.colorscheme;
          Breeze = {
            General = {
              Anchor = "0.5,0.5";
              Blur = true;
              ColorRandomization = false;
              Description = "Breeze";
              FillStyle = "Tile";
              Opacity = 0.96;
              Wallpaper = ./cool-wallpaper.png;
              WallpaperFlipType = "NoFlip";
              WallpaperOpacity = 1;
            };
            Foreground.Color = "252,252,252";
            ForegroundFaint.Color = "239,240,241";
            ForegroundIntense.Color = "61,174,233";
            Background.Color = "35,38,39";
            BackgroundFaint.Color = "49,54,59";
            BackgroundIntense.Color = "0,0,0";
            Color0.Color = "35,38,39";
            Color0Faint.Color = "49,54,59";
            Color0Intense.Color = "127,140,141";
            Color1.Color = "127,140,141";
            Color1Faint.Color = "120,50,40";
            Color1Intense.Color = "192,57,43";
            Color2.Color = "17,209,22";
            Color2Faint.Color = "23,162,98";
            Color2Intense.Color = "28,220,154";
            Color3.Color = "246,116,0";
            Color3Faint.Color = "182,86,25";
            Color3Intense.Color = "253,188,75";
            Color4.Color = "29,153,243";
            Color4Faint.Color = "27,102,143";
            Color4Intense.Color = "61,174,233";
            Color5.Color = "155,89,182";
            Color5Faint.Color = "97,74,115";
            Color5Intense.Color = "142,68,173";
            Color6.Color = "26,188,156";
            Color6Faint.Color = "24,108,96";
            Color6Intense.Color = "22,160,133";
            Color7.Color = "252,252,252";
            Color7Faint.Color = "99,104,109";
            Color7Intense.Color = "255,255,255";
          }
        }
      '';
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
      type = with lib.types; attrsOf (attrsOf basicSettingsType);
      default = { };
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
      (lib.mapAttrs (
        groupName: (lib.mapAttrs (keyName: keyAttrs: { value = keyAttrs; }))
      ) cfg.extraConfig)
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
        lib.mkMerge (
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
        )
      ))
      (lib.attrsets.mapAttrs' (
        name: value:
        lib.attrsets.nameValuePair "konsole/${name}.colorscheme" {
          source =
            if builtins.isPath value then value else iniFormat.generate "konsole-${name}.colorscheme" value;
        }
      ) cfg.customColorSchemes)
    ];
  };
}
