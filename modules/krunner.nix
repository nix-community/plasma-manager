{ config, lib, ... }:
let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.krunner = {
    position = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "top"
          "center"
        ]);
      default = null;
      example = "center";
      description = "Set KRunner's position on the screen.";
    };
    activateWhenTypingOnDesktop = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = true;
      description = "Whether to activate KRunner when typing on the desktop.";
    };
    historyBehavior = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "disabled"
          "enableSuggestions"
          "enableAutoComplete"
        ]);
      default = null;
      example = "disabled";
      description = "Set the behavior of KRunner’s history.";
    };
  };

  config.programs.plasma.configFile."krunnerrc" = (
    lib.mkMerge [
      (lib.mkIf (cfg.krunner.position != null) {
        General.FreeFloating = cfg.krunner.position == "center";
      })
      (lib.mkIf (cfg.krunner.activateWhenTypingOnDesktop != null) {
        General.ActivateWhenTypingOnDesktop = cfg.krunner.activateWhenTypingOnDesktop;
      })
      (lib.mkIf (cfg.krunner.historyBehavior != null) {
        General.historyBehavior = (
          if cfg.krunner.historyBehavior == "enableSuggestions" then
            "CompletionSuggestion"
          else if cfg.krunner.historyBehavior == "enableAutoComplete" then
            "ImmediateCompletion"
          else
            "Disabled"
        );
      })
    ]
  );
}
