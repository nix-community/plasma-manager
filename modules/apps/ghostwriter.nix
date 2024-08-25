{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ghostwriter;
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
  };

  config = (lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  });
}