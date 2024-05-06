{ lib, ... } @ args:
let
  args' = args // {
    widgets = self;
  };

  sources = lib.mergeAttrsList (map (s: import s args') [
    ./battery.nix
    ./digital-clock.nix
    ./system-monitor.nix
    ./system-tray.nix
  ]);

  compositeWidgetType = lib.pipe sources [
    (builtins.mapAttrs (_: s:
      lib.mkOption {
        inherit (s) description;
        type = lib.types.submodule {
          options = s.opts;
        };
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
        type = with lib.types; nullOr (attrsOf (attrsOf (either str (listOf str))));
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

    type = lib.types.either compositeWidgetType simpleWidgetType;

    lib = import ./lib.nix (args // { widgets = self; });

    convert = composite:
      let
        inherit (builtins) length head attrNames mapAttrs isAttrs;
        keys = attrNames composite;
        type = head keys;

        converters = mapAttrs (_: s: s.convert) sources;
      in
      if isAttrs composite && length keys == 1 && isKnownWidget type 
      then {
        config = null;
        extraConfig = "";
      } // converters.${type} composite.${type}
      else composite; # not a known composite type
  };
in
  self
