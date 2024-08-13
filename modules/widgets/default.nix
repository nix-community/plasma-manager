{ lib, ... } @ args:
let
  args' = args // {
    widgets = self;
  };

  sources = lib.attrsets.mergeAttrsList (map (s: import s args') [
    ./application-title-bar.nix
    ./battery.nix
    ./digital-clock.nix
    ./icon-tasks.nix
    ./keyboard-layout.nix
    ./kicker.nix
    ./kickerdash.nix
    ./kickoff.nix
    ./plasma-panel-colorizer.nix
    ./plasmusic-toolbar.nix
    ./system-monitor.nix
    ./system-tray.nix
  ]);

  compositeWidgetType = lib.pipe sources [
    (builtins.mapAttrs
      (_: s: lib.mkOption {
        inherit (s) description;
        type = lib.types.submodule (submoduleArgs: {
          options = if builtins.isFunction s.opts then s.opts submoduleArgs else s.opts;
        });
      }))
    lib.types.attrTag
  ];

  simpleWidgetType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "org.kde.plasma.kickoff";
        description = "The name of the widget to add.";
      };
      config = lib.mkOption {
        type = (import ./lib.nix (args // { widgets = self; })).configValueType;
        default = null;
        example = {
          General.icon = "nix-snowflake-white";
        };
        description = '' 
          Configuration options for the widget.

          See https://develop.kde.org/docs/plasma/scripting/keys/ for an (incomplete) list of options
          that can be set here.
        '';
      };
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = ''
          (widget) => {
            widget.currentConfigGroup = ["General"];
            widget.writeConfig("title", "My widget");
          }
        '';
        description = ''
          Extra configuration for the widget in JavaScript.

          Should be a lambda/anonymous function that takes the widget as its sole argument,
          which can then be called by the script.
        '';
      };
    };
  };

  isKnownWidget = lib.flip builtins.hasAttr sources;

  self = {
    inherit isKnownWidget;

    type = lib.types.oneOf [ lib.types.str compositeWidgetType simpleWidgetType ];

    lib = import ./lib.nix (args // { widgets = self; });

    convert = widget:
      let
        inherit (builtins) length head attrNames mapAttrs isAttrs isString;
        keys = attrNames widget;
        type = head keys;

        base = {
          config = null;
          extraConfig = "";
        };
        converters = mapAttrs (_: s: s.convert) sources;
      in
      if isString widget then
        base // { name = widget; }
      else if isAttrs widget && length keys == 1 && isKnownWidget type then
        base // converters.${type} widget.${type}
      else widget; # not a known composite type
  };
in
self
