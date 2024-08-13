{ lib, ... }:
let
  inherit (lib)
    optionalString
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    filterAttrs
    splitString;

  configValueTypes = with lib.types; oneOf [ bool float int str ];
  configValueTypeInner = with lib.types; either configValueTypes (listOf configValueTypes);
  configValueType = with lib.types; nullOr (attrsOf (either configValueTypeInner (attrsOf configValueTypeInner)));

  # any value or null -> string -> string 
  # If value is null, returns the empty string, otherwise returns the provided string
  stringIfNotNull = v: optionalString (v != null);

  # Converts each datatype into an expression which can be parsed in JavaScript
  valToJS = v: if (builtins.isString v) then ''"${v}"'' else if (builtins.isBool v) then (lib.boolToString v) else (builtins.toString v);

  # Converts a list of  to a single string, that can be parsed as a string list in JavaScript
  toJSList = values: ''[${concatMapStringsSep ", " valToJS values}]'';

  setWidgetSettings = var: settings:
    let
      perConfig = key: value: ''${var}.writeConfig("${key}", ${
  if builtins.isList value
  then toJSList value
  else valToJS value
    });'';

      perGroup = group: configs: ''
        ${var}.currentConfigGroup = ${toJSList (splitString "/" group)};
        ${concatStringsSep "\n" (mapAttrsToList perConfig configs)}
      '';

      groups = (filterAttrs (_: value: builtins.isAttrs value) settings);
      topLevel = (filterAttrs (_: value: !builtins.isAttrs value) settings);
    in
    concatStringsSep "\n" (
      (lib.optional (topLevel != {}) "${var}.currentConfigGroup = [];") ++
      (mapAttrsToList perConfig topLevel) ++

      (mapAttrsToList perGroup groups));

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
in
{
  inherit
    stringIfNotNull
    setWidgetSettings
    addWidgetStmts
    configValueType;
}
