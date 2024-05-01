{lib, ...} @ args: let
  sources = lib.mergeAttrsList (map (s: import s args) [
    ./system-monitor.nix
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
        description = "Extra configuration-options for the widget.";
      };
    };
  };
in {
  type = lib.types.either compositeWidgetType simpleWidgetType;

  convert = composite: let
    inherit (builtins) head attrNames;
    keys = attrNames composite;
    type = head keys;
  in
    if composite ? name
    then composite # simple
    else (builtins.mapAttrs (_: s: s.convert) sources).${type} composite.${type};
}
