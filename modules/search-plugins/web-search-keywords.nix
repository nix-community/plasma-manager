{ config, lib, ... }:

let
  cfg = config.programs.plasma.searchPlugins.webSearchKeywords;

  webSearchKeyword = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          description = "The name of this web search keyword.";
          default = name;
          defaultText = "<name>";
          type = lib.types.str;
        };
        keys = lib.mkOption {
          description = "The keys that trigger this web search engine.";
          default = null;
          type = with lib.types; listOf str;
        };
        query = lib.mkOption {
          description = ''
            The URI that is used to perform the search on the search engine here.

            The whole text to be searched for can be specified as `\{@}` or `\{0}`. Recommended is `\{@}`, since it removes all query variables (`key=value` pairs) from the resulting string, whereas `\{0}` will be substituted with the unmodified query string.

            You can use `\{1}...\{n}` to specify certain words from the query and `\{key}` to specify a value given by `key=value` in the user query.

            In addition it is possible to specify multiple references (keys, numbers and strings) at once, i.e. `\{1,key,...,"default"}`. The first matching value (from the left) will be used as the substitution value for the resulting URI. A quoted string can be used as the default value if nothing matches from the left of the reference list.
          '';
          default = null;
          type = lib.types.strMatching ".*\\\\\\{[@0]}.*";
        };
      };
    }
  );

  mkWebSearchKeywordConfigFile = keyword: /* desktop */ ''
    [Desktop Entry]
    Charset=
    Hidden=false
    Keys=${lib.concatStringsSep "," keyword.keys}
    Name=${keyword.name}
    Query=${lib.escape [ "\\" ] keyword.query}
    Type=Service
  '';

in
{

  options.programs.plasma.searchPlugins.webSearchKeywords = {

    enable = lib.mkEnableOption "the web search keywords plugin." // {
      default = true;
    };

    delimiter = lib.mkOption {
      description = ''
        The delimiter that separates the keyword from the search terms.
      '';
      example = ">";
      default = ":";
      type = lib.types.str;
    };

    default = lib.mkOption {
      description = ''
        The default web search keyword that is used if no keyword was specified.
      '';
      example = "duckduckgo";
      default = null;
      type = with lib.types; nullOr str;
    };

    preferred = lib.mkOption {
      description = ''
        These web search keywords that are prioritised if there are too many results.
      '';
      example = [
        "duckduckgo"
        "wikipedia"
      ];
      default = [ ];
      type = with lib.types; listOf str;
    };

    usePreferredOnly = lib.mkOption {
      description = "Whether to use only the preferred keywords.";
      example = true;
      default = false;
      type = lib.types.bool;
    };

    extra = lib.mkOption {
      description = "Extra keywords to be added.";
      example = {
        nixpkgs = {
          keys = [
            "np"
            "nixpkgs"
          ];
          query = "https://search.nixos.org/packages?channel=unstable&query=\\{@}";
        };
      };
      default = { };
      type = lib.types.attrsOf webSearchKeyword;
    };

  };

  config = {
    assertions = lib.mapAttrsToList (attr: keyword: {
      assertion = lib.length keyword.keys >= 1;
      message = ''
        No trigger keys are defined for the '${keyword.name}' Plasma web search keyword.
        Set it through '${
          lib.options.showOption [
            "programs"
            "plasma"
            "webSearchKeyword"
            attr
            "keys"
          ]
        }'.
      '';
    }) cfg.extra;

    programs.plasma.configFile.kuriikwsfilterrc.General = {
      DefaultWebShortcut = cfg.default;
      EnableWebShortcuts = cfg.enable;
      KeywordDelimiter = cfg.delimiter;
      PreferredWebShortcuts = lib.concatStringsSep "," cfg.preferred;
      UsePreferredWebShortcutsOnly = cfg.usePreferredOnly;
    };

    xdg.dataFile = lib.mapAttrs' (id: keyword: {
      name = "kf6/searchproviders/${id}.desktop";
      value.text = mkWebSearchKeywordConfigFile keyword;
    }) cfg.extra;
  };

}
