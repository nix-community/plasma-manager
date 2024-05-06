{ lib, widgets, ... }:
let
  inherit (lib)
    optionalString
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    splitString
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
      perConfig = key: value: ''${var}.writeConfig("${key}", ${
      if builtins.isString value
      then wrapInQuotes value
      else toJSStringList value
    });'';
      perGroup = group: configs: ''
        ${var}.currentConfigGroup = ${toJSStringList (splitString "/" group)};
        ${concatStringsSep "\n" (mapAttrsToList perConfig configs)}
      '';
    in
    concatStringsSep "\n" (mapAttrsToList perGroup settings);

  addWidgetStmts = containment: var: ws:
    let
      widgetConfigsToStmts = widget: ''
        var w = ${var}["${widget.name}"];
        ${setWidgetSettings "w" widget.config}
      '';

      addStmt = widget:
        let
          widget' = widgets.convert widget;
          createWidget = name: ''${var}["${name}"] = ${containment}.addWidget("${name}");'';
        in
        if builtins.isString widget
        then createWidget widget
        else
          ''
            ${createWidget widget'.name}
            ${stringIfNotNull widget'.config (widgetConfigsToStmts widget')}
            ${lib.optionalString (widget'.extraConfig != "") ''
              (${widget'.extraConfig})(${var}["${widget'.name}"]);
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
in
{
  inherit
    stringIfNotNull
    setWidgetSettings
    addWidgetStmts
    boolToString'
    getEnum
    ;
}
