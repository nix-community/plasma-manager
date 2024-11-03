{ config, lib, ... }:
let
  cfg = config.programs.plasma;
in
{
  options.programs.plasma.session = {
    general = {
      askForConfirmationOnLogout = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Whether to ask for confirmation when shutting down, restarting or logging out";
      };
    };
    sessionRestore = {
      restoreOpenApplicationsOnLogin = lib.mkOption {
        type =
          with lib.types;
          nullOr (enum [
            "onLastLogout"
            "whenSessionWasManuallySaved"
            "startWithEmptySession"
          ]);
        default = null;
        example = "startWithEmptySession";
        description = ''
          Controls how applications are restored on login:
          - "onLastLogout": Restores applications that were open during the last logout.
          - "whenSessionWasManuallySaved": Restores applications based on a manually saved session.
          - "startWithEmptySession": Starts with a clean, empty session each time.
        '';
        apply =
          option:
          if option == null then
            null
          else if option == "onLastLogout" then
            "restorePreviousLogout"
          else if "whenSessionWasManuallySaved" then
            "restoreSavedSession"
          else
            "emptySession";
      };
      excludeApplications = lib.mkOption {
        type = with lib.types; nullOr (listOf str);
        default = null;
        example = [
          "firefox"
          "xterm"
        ];
        description = "List of applications to exclude from session restore";
        apply = apps: if apps == null then null else builtins.concatStringsSep "," apps;
      };
    };
  };

  config.programs.plasma.configFile."ksmserverrc".General = lib.mkMerge [
    (lib.mkIf (cfg.session.general.askForConfirmationOnLogout != null) {
      confirmLogout = cfg.session.general.askForConfirmationOnLogout;
    })
    (lib.mkIf (cfg.session.sessionRestore.excludeApplications != null) {
      excludeApps = cfg.session.sessionRestore.excludeApplications;
    })
    (lib.mkIf (cfg.session.sessionRestore.restoreOpenApplicationsOnLogin != null) {
      loginMode = cfg.session.sessionRestore.restoreOpenApplicationsOnLogin;
    })
  ];
}
