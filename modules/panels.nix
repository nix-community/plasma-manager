{
  lib,
  config,
  pkgs,
  ...
}@args:
let
  cfg = config.programs.plasma;
  desktopWidgets = if cfg.desktop.widgets != null then cfg.desktop.widgets else [ ];
  hasWidget =
    widgetName:
    builtins.any (panel: builtins.any (widget: widget.name == widgetName) panel.widgets) cfg.panels
    || builtins.any (widget: widget.name == widgetName) desktopWidgets;

  # An attrset keeping track of the packages which should be added when a
  # widget is present in the config.
  additionalWidgetPackages = with pkgs; {
    "com.github.antroids.application-title-bar" = [ application-title-bar ];
    plasmusic-toolbar = [ plasmusic-toolbar ];
    "luisbocanegra.panel.colorizer" = [ plasma-panel-colorizer ];
    "org.kde.windowbuttons" = [ kdePackages.applet-window-buttons6 ];
    "org.dhruv8sh.kara" = [ kara ];
  };
  # An attrset of service-names and widgets/conditions. If any of the
  # conditions (given in cond) evaluate to true for any of the widgets with the
  # name given in the widget attribute, the service is marked for restart in
  # the panel-script.
  serviceRestarts = {
    "plasma-plasmashell" = [
      {
        widget = "org.kde.plasma.systemmonitor";
        cond =
          widget:
          (
            (builtins.hasAttr "org.kde.ksysguard.piechart/General" widget.config)
            && (builtins.hasAttr "showLegend" widget.config."org.kde.ksysguard.piechart/General")
          );
      }
    ];
  };
  widgetsOfName =
    name: (lib.filter (w: w.name == name) (lib.flatten (map (panel: panel.widgets) cfg.panels)));
  shouldRestart =
    service:
    (
      let
        candidates = serviceRestarts."${service}";
      in
      (builtins.any (x: x) (map (v: (builtins.any v.cond (widgetsOfName v.widget))) candidates))
    );

  widgets = import ./widgets args;

  panelType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        height = lib.mkOption {
          type = lib.types.int;
          default = 44;
          description = "The height of the panel.";
        };
        offset = lib.mkOption {
          type = with lib.types; nullOr int;
          default = null;
          example = 100;
          description = "The offset of the panel from the anchor-point.";
        };
        minLength = lib.mkOption {
          type = with lib.types; nullOr int;
          default = null;
          example = 1000;
          description = "The minimum required length/width of the panel.";
        };
        maxLength = lib.mkOption {
          type = with lib.types; nullOr int;
          default = null;
          example = 1600;
          description = "The maximum allowed length/width of the panel.";
        };
        lengthMode = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "fit"
              "fill"
              "custom"
            ]);
          default = if config.minLength != null || config.maxLength != null then "custom" else null;
          example = "fit";
          description = "The length mode of the panel. Defaults to `custom` if either `minLength` or `maxLength` is set.";
        };
        location = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "top"
              "bottom"
              "left"
              "right"
              "floating"
            ]);
          default = "bottom";
          example = "left";
          description = "The location of the panel.";
        };
        alignment = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "left"
              "center"
              "right"
            ]);
          default = "center";
          example = "right";
          description = "The alignment of the panel.";
        };
        hiding = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "none"
              "autohide"
              # Plasma 5 only
              "windowscover"
              "windowsbelow"
              # Plasma 6 only
              "dodgewindows"
              "normalpanel"
              "windowsgobelow"
            ]);
          default = null;
          example = "autohide";
          description = ''
            The hiding mode of the panel. Here, `windowscover` and `windowsbelow` are
            Plasma 5-only, while `dodgewindows`, `windowsgobelow` and `normalpanel` are
            Plasma 6-only.
          '';
        };
        floating = lib.mkEnableOption "Enable or disable floating style.";
        widgets = lib.mkOption {
          type = lib.types.listOf widgets.type;
          default = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.pager"
            "org.kde.plasma.icontasks"
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
            "org.kde.plasma.showdesktop"
          ];
          example = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.icontasks"
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.digitalclock"
          ];
          description = ''
            The widgets to use in the panel. To get the names, it may be useful
            to look in the `share/plasma/plasmoids` subdirectory in the Nix Store path the
            widget/plasmoid is sourced from. Some packages which include some
            widgets/plasmoids are, for example, `plasma-desktop` and
            `plasma-workspace`.
          '';
          apply = map widgets.convert;
        };
        screen = lib.mkOption {
          type =
            with lib.types;
            nullOr (oneOf [
              ints.unsigned
              (listOf ints.unsigned)
              (enum [ "all" ])
            ]);
          default = null;
          description = ''
            The screen the panel should appear on. Can be an `int`, or a `list of ints`,
            starting from `0`, representing the ID of the screen the panel should
            appear on. Alternatively, it can be set to `all` if the panel should
            appear on all the screens.
          '';
        };
        extraSettings = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            Extra lines to add to the `layout.js`. See
            the [KDE Documentation](https://develop.kde.org/docs/plasma/scripting) for information.
          '';
        };
      };
    }
  );

  anyPanelSet = (builtins.length cfg.panels) > 0;
in
{
  imports = [
    (lib.mkRemovedOptionModule [
      "programs"
      "plasma"
      "extraWidgets"
    ] "Place the widget packages in home.packages or environment.systemPackages instead.")
  ];

  options.programs.plasma.panels = lib.mkOption {
    type = lib.types.listOf panelType;
    default = [ ];
  };

  config = (
    lib.mkIf cfg.enable {
      home.packages = (
        lib.flatten (
          lib.filter (x: x != null) (
            lib.mapAttrsToList (
              widgetName: packages: if (hasWidget widgetName) then packages else null
            ) additionalWidgetPackages
          )
        )
      );

      programs.plasma.startup.desktopScript."panels" = (
        lib.mkIf anyPanelSet (
          let
            anyNonDefaultScreens = ((builtins.any (panel: panel.screen != null)) cfg.panels);
            panelPreCMD = ''
              # We delete plasma-org.kde.plasma.desktop-appletsrc to hinder it
              # growing indefinitely. See:
              # https://github.com/nix-community/plasma-manager/issues/76
              [ -f ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc ] && rm ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
            '';
            panelLayoutStr = (
              import ../lib/panel.nix {
                inherit lib;
                inherit config;
              }
            );
            panelPostCMD = (
              if anyNonDefaultScreens then
                ''
                  sed -i 's/^lastScreen\\x5b$i\\x5d=/lastScreen[$i]=/' ${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc
                ''
              else
                ""
            );
          in
          {
            preCommands = panelPreCMD;
            text = panelLayoutStr;
            postCommands = panelPostCMD;
            restartServices = (
              lib.unique (if anyNonDefaultScreens then [ "plasma-plasmashell" ] else [ ])
              ++ (lib.filter (service: shouldRestart service) (builtins.attrNames serviceRestarts))
            );
            priority = 2;
          }
        )
      );
    }
  );
}
