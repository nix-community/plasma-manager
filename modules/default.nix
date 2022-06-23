{ lib, ... }:

{
  imports = [
    ./files.nix
    ./hotkeys.nix
    ./shortcuts.nix
    ./windows.nix
    ./workspace.nix
  ];

  options.programs.plasma.enable = lib.mkEnableOption ''
    Enable configuration management for KDE Plasma.
  '';
}
