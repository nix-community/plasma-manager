{ config, lib, ... }:
let cfg = config.programs.plasma;
in with lib; {
  options.programs.plasma.krunner = {
    position = mkOption {
      type = with types; nullOr (enum [ "Top" "Center" ]);
      default = null;
      example = "Center";
      description = "Position of KRunner on screen.";
    };
    activateWhenTypingOnDesktop = mkOption {
      type = with types; nullOr bool;
      default = null;
      description = "Activate KRunner when typing on the desktop.";
    };
    historyBehavior = mkOption {
      type = with types;
        nullOr (enum [ "Disabled" "EnableSuggestions" "EnableAutoComplete" ]);
      default = null;
      example = "Disabled";
      description = "Behavior of KRunner’s history.";
    };
  };

  config.programs.plasma.configFile."krunnerrc" = (mkMerge [
    (mkIf (cfg.krunner.position != null) {
      General.FreeFloating = cfg.krunner.position == "Center";
    })
    (mkIf (cfg.krunner.activateWhenTypingOnDesktop != null) {
      General.ActivateWhenTypingOnDesktop =
        cfg.krunner.activateWhenTypingOnDesktop;
    })
    (mkIf (cfg.krunner.historyBehavior != null) {
      General.historyBehavior =
        (if cfg.krunner.historyBehavior == "EnableSuggestions" then
          "CompletionSuggestion"
        else if cfg.krunner.historyBehavior == "EnableAutoComplete" then
          "ImmediateCompletion"
        else
          cfg.krunner.historyBehavior);
    })
  ]);
}
