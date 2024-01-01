# Manage KDE Plasma with Home Manager

This project aims to provide [Home Manager][home-manager] modules which allow you
to configure KDE Plasma using Nix.

Configuration is broken down into three layers:

  1. High-level interface like many Home Manager modules:

     ```nix
     {
       programs.plasma = {
         workspace = {
           clickItemTo = "select";
           tooltipDelay = 5;
           theme = "breeze-dark";
           colorScheme = "BreezeDark";
           wallpaper = "${pkgs.libsForQt5.plasma-workspace-wallpapers}/share/wallpapers/Kay/contents/images/1080x1920.png";
         };

         kwin.titlebarButtons = {
          left = [ "on-all-desktops" "keep-above-windows" ];
          right = [ "help" "minimize" "maximize" "close" ]
        };
         
         spectacle.shortcuts = {
           captureActiveWindow = "Meta+Print";
           captureCurrentMonitor = "Print";
           captureEntireDesktop = "Shift+Print";
           captureRectangularRegion = "Meta+Shift+S";
           captureWindowUnderCursor = "Meta+Ctrl+Print";
           launch = "Meta+S";
           launchWithoutCapturing = "Meta+Alt+S";
         };
       };
     }
     ```

     This layer is doesn't currently have many options.  If using a
     high-level interface like this sounds interesting to you please
     consider contributing more options.

  2. Mid-level interface:

     ```nix
     {
       programs.plasma = {
         shortcuts.kwin = {
           "Switch Window Down" = "Meta+J";
           "Switch Window Left" = "Meta+H";
           "Switch Window Right" = "Meta+L";
           "Switch Window Up" = "Meta+K";
         };
       };
     }
     ```

     This layer is considered mid level because, while it generates a
     great deal of configuration for you, you must still know the name
     of the corresponding KDE setting to use it.  (See information
     about the `rc2nix` tool below.)

  3. A low-level interface:

     ```nix
     {
       programs.plasma = {
         configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
       };
     }
     ```

     The other two layers ultimately generate Nix configuration for
     this low-level layer.  Configuration at this level is essentially
     in the final state before being sent to the `kwriteconfig5` tool.

An example is available in the `example` directory.

## Capturing Your Current Configuration

To make it easier to migrate to Plasma Manger, and to help maintain
your Nix configuration, this project includes a tool called `rc2nix`.

This tool will read KDE configuration files and translate them to
Nix.  The translated configuration is written to standard output.
This makes it easy to:

  * Generate an initial Plasma Manager configuration file.

  * See what settings are changed by a GUI tool by capturing a file
    before and after using the tool and then using `diff`.

To run the `rc2nix` tool without having to clone this repository run
the following shell command:

```sh
nix run github:pjones/plasma-manager
```

## Contributions and Maintenance

I consider this a community project and welcome all contributions.  If
there's enough interest I would love to move this into
[nix-community][] once it has matured.

That said, this project works well enough for my needs.  I don't have
enough free time to maintain this project on my own.  Therefore I
won't be able to fix issues or implement new features without help.

## Special Thanks

This work was inspired by the suggestions on [Home Manger Issue
#607][hm607] by people such as [bew](https://github.com/bew) and [kurnevsky](https://github.com/kurnevsky).  Thank you.

[home-manager]: https://github.com/nix-community/home-manager
[hm607]: https://github.com/nix-community/home-manager/issues/607
[nix-community]: https://github.com/nix-community
