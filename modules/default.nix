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
    ./shortcuts.nix
    ./spectacle.nix
    ./startup.nix
    ./windows.nix
    ./window-rules.nix
    ./workspace.nix
    ./input.nix
  ];

  options.programs.plasma.enable = lib.mkEnableOption ''
    Enable configuration management for KDE Plasma.
  '';
}
