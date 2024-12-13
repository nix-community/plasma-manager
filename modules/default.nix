{ lib, ... }:

{
  imports = [
    ./apps
    ./desktop.nix
    ./files.nix
    ./fonts.nix
    ./hotkeys.nix
    ./input.nix
    ./krunner.nix
    ./kscreenlocker.nix
    ./kwin.nix
    ./panels.nix
    ./powerdevil.nix
    ./session.nix
    ./shortcuts.nix
    ./spectacle.nix
    ./startup.nix
    ./window-rules.nix
    ./windows.nix
    ./workspace.nix
  ];

  options.programs.plasma.enable = lib.mkEnableOption ''
    declarative configuration options for the KDE Plasma Desktop.
  '';
}
