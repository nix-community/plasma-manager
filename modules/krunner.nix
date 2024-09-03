{ config, lib, ... }:
let cfg = config.programs.plasma;
in {
  options.programs.plasma.krunner = {
    position = lib.mkOption {
      type = with lib.types; nullOr (enum [ "top" "center" ]);
      default = null;
      example = "center";
      description = "Position of KRunner on screen.";
    };
    activateWhenTypingOnDesktop = mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      description = "Activate KRunner when typing on the desktop.";
    };
    historyBehavior = mkOption {
      type = with lib.types;
        nullOr (enum [ "disabled" "enableSuggestions" "enableAutoComplete" ]);
      default = null;
      example = "disabled";
      description = "Behavior of KRunner’s history.";
    };
  };

  config.programs.plasma.configFile."krunnerrc" = (lib.mkMerge [
    (lib.mkIf (cfg.krunner.position != null) {
      General.FreeFloating = cfg.krunner.position == "center";
    })
    (lib.mkIf (cfg.krunner.activateWhenTypingOnDesktop != null) {
      General.ActivateWhenTypingOnDesktop =
        cfg.krunner.activateWhenTypingOnDesktop;
    })
    (lib.mkIf (cfg.krunner.historyBehavior != null) {
      General.historyBehavior =
        (if cfg.krunner.historyBehavior == "enableSuggestions" then
          "CompletionSuggestion"
        else if cfg.krunner.historyBehavior == "enableAutoComplete" then
          "ImmediateCompletion"
        else
          "Disabled");
    })
  ]);
}
