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
      restoreOpenApplicationsOnLogin =
        let
          options = {
            onLastLogout = "restorePreviousLogout";
            whenSessionWasManuallySaved = "restoreSavedSession";
            startWithEmptySession = "emptySession";
          };
        in
        lib.mkOption {
          type = with lib.types; nullOr (enum (builtins.attrNames options));
          default = null;
          example = "startWithEmptySession";
          description = ''
            Controls how applications are restored on login:
            - "onLastLogout": Restores applications that were open during the last logout.
            - "whenSessionWasManuallySaved": Restores applications based on a manually saved session.
            - "startWithEmptySession": Starts with a clean, empty session each time.
          '';
          apply = option: if option == null then null else options.${option};
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
