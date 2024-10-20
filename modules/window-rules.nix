{ lib, config, ... }:
with lib.types;
let
  inherit (builtins)
    length
    listToAttrs
    foldl'
    toString
    attrNames
    getAttr
    concatStringsSep
    add
    isAttrs
    ;
  inherit (lib) mkOption mkIf;
  inherit (lib.trivial) mergeAttrs;
  inherit (lib.lists) imap0;
  inherit (lib.attrsets) optionalAttrs filterAttrs mapAttrsToList;
  cfg = config.programs.plasma;
  applyRules = {
    "do-not-affect" = 1;
    "force" = 2;
    "initially" = 3;
    "remember" = 4;
  };
  matchRules = {
    "exact" = 1;
    "substring" = 2;
    "regex" = 3;
  };
  windowTypes = {
    normal = 1;
    desktop = 2;
    dock = 4;
    toolbar = 8;
    torn-of-menu = 16;
    dialog = 32;
    menubar = 128;
    utility = 256;
    spash = 512;
    osd = 65536;
  };
  matchNameMap = {
    "window-class" = "wmclass";
    "window-types" = "types";
    "window-role" = "windowrole";
  };
  matchOptionType =
    hasMatchWhole:
    submodule {
      options =
        {
          value = mkOption {
            type = str;
            description = "Name to match.";
          };
          type = mkOption {
            type = enum (attrNames matchRules);
            default = "exact";
            description = "Name match type.";
          };
        }
        // optionalAttrs hasMatchWhole {
          match-whole = mkOption {
            type = bool;
            default = true;
            description = "Match whole name.";
          };
        };
    };
  basicValueType = oneOf [
    bool
    float
    int
    str
  ];
  applyOptionType = submodule {
    options = {
      value = mkOption {
        type = basicValueType;
        description = "Value to set.";
      };
      apply = mkOption {
        type = enum (attrNames applyRules);
        default = "initially";
        description = "How to apply the value.";
      };
    };
  };
  mkMatchOption =
    name: hasMatchWhole:
    mkOption {
      type = nullOr (coercedTo str (value: { inherit value; }) (matchOptionType hasMatchWhole));
      default = null;
      description = "${name} matching.";
    };
  fixMatchName = name: matchNameMap.${name} or name;
  buildMatchRule =
    name: rule:
    (
      {
        "${fixMatchName name}" = rule.value;
        "${fixMatchName name}match" = getAttr rule.type matchRules;
      }
      // optionalAttrs (rule ? match-whole) { "${fixMatchName name}complete" = rule.match-whole; }
    );
  buildApplyRule = name: rule: {
    "${name}" = rule.value;
    "${name}rule" = getAttr rule.apply applyRules;
  };
  buildWindowRule =
    rule:
    let
      matchOptions = filterAttrs (_name: isAttrs) rule.match;
      matchRules = mapAttrsToList buildMatchRule matchOptions;
      applyRules = mapAttrsToList buildApplyRule rule.apply;
      combinedRules = foldl' mergeAttrs { } (matchRules ++ applyRules);
    in
    {
      Description = rule.description;
    }
    // optionalAttrs (rule.match.window-types != 0) { types = rule.match.window-types; }
    // combinedRules;
  windowRules = listToAttrs (
    imap0 (i: rule: {
      name = toString (i + 1);
      value = buildWindowRule rule;
    }) cfg.window-rules
  );
in
{
  options.programs.plasma = {
    window-rules = mkOption {
      type = listOf (submodule {
        options = {
          match = mkOption {
            type = submodule {
              options = {
                window-class = mkMatchOption "Window class" true;
                window-role = mkMatchOption "Window role" false;
                title = mkMatchOption "Title" false;
                machine = mkMatchOption "clientmachine" false;
                window-types = mkOption {
                  type = listOf (enum (attrNames windowTypes));
                  default = [ ];
                  description = "Window types to match.";
                  apply = values: foldl' add 0 (map (val: getAttr val windowTypes) values);
                };
              };
            };
          };
          apply = mkOption {
            type = attrsOf (coercedTo basicValueType (value: { inherit value; }) applyOptionType);
            default = { };
            description = "Values to apply.";
          };
          description = mkOption {
            type = str;
            description = "Value to set.";
          };
        };
      });
      description = "KWin window rules.";
      default = [ ];
    };
  };

  config = mkIf (length cfg.window-rules > 0) {
    programs.plasma.configFile = {
      kwinrulesrc = {
        General = {
          count = length cfg.window-rules;
          rules = concatStringsSep "," (attrNames windowRules);
        };
      } // windowRules;
    };
  };
}
