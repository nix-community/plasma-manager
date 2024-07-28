{ lib, ... }:

{
  imports = [
    ./apps
    ./files.nix
    ./fonts.nix
    ./hotkeys.nix
    ./kscreenlocker.nix
    ./kwin.nix
    ./panels.nix
    ./powerdevil.nix
    ./shortcuts.nix
    ./spectacle.nix
    ./startup.nix
    ./window-rules.nix
    ./windows.nix
    ./workspace.nix
  ];

  options.programs.plasma.enable = lib.mkEnableOption ''
    Enable configuration management for KDE Plasma.
  '';
}
