{ lib, ... }:

{
  imports = [
    ./files.nix
    ./hotkeys.nix
    ./shortcuts.nix
    ./spectacle.nix
    ./windows.nix
    ./workspace.nix
    ./kwin.nix
    ./startup.nix
    ./panels.nix
    ./input.nix
    ./apps
  ];

  options.programs.plasma.enable = lib.mkEnableOption ''
    Enable configuration management for KDE Plasma.
  '';
}
