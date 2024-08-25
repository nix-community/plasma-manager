{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ghostwriter;

  createThemes = lib.attrsets.mapAttrs' (name: value: lib.attrsets.nameValuePair
    ("ghostwriter/${name}.json")
    ({ enable = true; source = value; })
  );
in
{
  options.programs.ghostwriter = {
    enable = lib.mkEnableOption ''
      Enable configuration management for Ghostwriter.
    '';

    package = lib.mkPackageOption pkgs [ "kdePackages" "ghostwriter" ] {
      example = "pkgs.kdePackages.ghostwriter";
      extraDescription = ''
        Use `pkgs.libsForQt5.ghostwriter` in Plasma5 and
        `pkgs.kdePackages.ghostwriter` in Plasma6.
      '';
    };

    theme = {
      name = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "Ghostwriter";
        description = ''
          The name of the theme to use.
        '';
      };
      customThemes = lib.mkOption {
        type = with lib.types; attrsOf path;
        default = { };
        description = ''
          Custom themes to be added to the installation. The key is their name.
          Choose them in `programs.ghostwriter.theme.name`.
        '';
      };
    };
  };

  config = (lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.dataFile = (createThemes cfg.theme.customThemes);
  });
}