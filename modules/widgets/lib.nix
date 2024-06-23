{ lib, widgets, ... }:
let
  inherit (lib)
    optionalString
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    splitString
    mkOption
    types
    ;

  # any value or null -> string -> string 
  # If value is null, returns the empty string, otherwise returns the provided string
  stringIfNotNull = v: optionalString (v != null);

  # string -> string
  # Wrap a string in double quotes.
  wrapInQuotes = s: ''"${s}"'';

  # list of strings -> string
  # Converts a list of strings to a single string, that can be parsed as a string list in JavaScript
  toJSStringList = values: ''[${concatMapStringsSep ", " wrapInQuotes values}]'';

  setWidgetSettings = var: settings:
    let
      perConfig = group: key: value: ''${var}.writeConfig("${key}", ${
        if builtins.isString value
        then wrapInQuotes value
        else if builtins.isList value
        then toJSStringList value
        else throw "widget config ${group}.${key} can only be string or string list, found ${builtins.typeOf value}"
      });'';

      perGroup = group: configs: ''
        ${var}.currentConfigGroup = ${toJSStringList (splitString "/" group)};
        ${concatStringsSep "\n" (mapAttrsToList (perConfig group) configs)}
      '';
    in
    concatStringsSep "\n" (mapAttrsToList perGroup settings);

  addWidgetStmts = containment: var: ws:
    let
      widgetConfigsToStmts = { name, config, ... }: ''
        var w = ${var}["${name}"];
        ${setWidgetSettings "w" config}
      '';

      addStmt = { name, config, extraConfig }@widget: ''
        ${var}["${name}"] = ${containment}.addWidget("${name}");
        ${stringIfNotNull config (widgetConfigsToStmts widget)}
        ${lib.optionalString (extraConfig != "") ''
          (${extraConfig})(${var}["${name}"]);
        ''}
      '';
    in
    ''
      const ${var} = {};
      ${lib.concatMapStringsSep "\n" addStmt ws}
    '';

  boolToString' = b: if b == null then null else lib.boolToString b;

  getEnum = es: e:
    if e == null
    then null
    else
      toString (
        lib.lists.findFirstIndex
          (x: x == e)
          (throw "getEnum: nonexistent key ${e}! This is a bug!")
          es
      );

  mkBoolOption = description: mkOption {
    inherit description;

    type = types.nullOr types.bool;
    default = null;
    example = true;
    apply = widgets.lib.boolToString';
  };

  mkEnumOption = enum: mkOption {
    type = types.nullOr (types.enum enum);
    default = null;
    apply = widgets.lib.getEnum enum;
  };
in
{
  inherit
    stringIfNotNull
    setWidgetSettings
    addWidgetStmts
    boolToString'
    getEnum
    mkBoolOption
    mkEnumOption
    ;
}
