{ config, lib, pkgs, ... }:
let
  cfg = config.programs.plasma;
  agent = "org.kde.plasma.favorites.applications";
  activity = ":global";
  rawList = lib.concatMapStringsSep " " (f: "'${f}'") cfg.kickoff.favorites;
  script = pkgs.writeShellScript "kickoff-favorites" ''
    AGENT="${agent}"
    ACTIVITY="${activity}"
    DB="${config.xdg.dataHome}/kactivitymanagerd/resources/database"
    APPLETSRC="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"
    STATSRC="${config.xdg.configHome}/kactivitymanagerd-statsrc"
    APPDIRS=""
    for d in $(printf '%s' "''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:''${XDG_DATA_HOME:-$HOME/.local/share}" | tr ':' ' '); do
      APPDIRS="$APPDIRS $d/applications"
    done
    APPDIRS="$APPDIRS /run/current-system/sw/share/applications"
    FIND=${pkgs.findutils}/bin/find
    AWK=${pkgs.gawk}/bin/awk
    SORT=${pkgs.coreutils}/bin/sort
    HEAD=${pkgs.coreutils}/bin/head
    BASENAME=${pkgs.coreutils}/bin/basename
    PASTE=${pkgs.coreutils}/bin/paste
    SED=${pkgs.gnused}/bin/sed
    QDBUS=${pkgs.kdePackages.qttools}/bin/qdbus
    SQLITE=${pkgs.sqlite}/bin/sqlite3
    KWRITECONFIG=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6
    resolve() (
      case "$1" in *://*) printf '%s\n' "$1"; return ;; esac
      for d in $APPDIRS; do
        [ -f "$d/$1" ] && { printf 'applications:%s\n' "$1"; return; }
      done
      base="''${1%.desktop}"
      pattern="*$(printf '%s' "$base" | tr ' ' '*')*"
      for d in $APPDIRS; do
        [ -d "$d" ] || continue
        m=$($FIND "$d" -maxdepth 1 -iname "$pattern.desktop" 2>/dev/null | $SORT | $HEAD -n1)
        [ -n "$m" ] && { printf 'applications:%s\n' "$($BASENAME "$m")"; return; }
      done
      echo "kickoff_favorites: no .desktop matched '$1', skipping" >&2
    )
    REFS=$(for f in ${rawList}; do resolve "$f"; done)
    link() { $QDBUS org.kde.ActivityManager /ActivityManager/Resources/Linking \
      org.kde.ActivityManager.ResourcesLinking."$1" "$AGENT" "$2" "$ACTIVITY" >/dev/null 2>&1; }
    if [ -f "$DB" ]; then
      CURRENT=$($SQLITE "$DB" \
        "select targettedResource from ResourceLink where usedActivity='$ACTIVITY' and initiatingAgent='$AGENT';" 2>/dev/null)
      for res in $CURRENT; do link UnlinkResourceFromActivity "$res"; done
    fi
    for r in $REFS; do link LinkResourceToActivity "$r"; done
    if [ -f "$APPLETSRC" ]; then
      IDS=$($AWK '
        /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ {
          split($0, p, "["); id = p[length(p)]; sub(/\]$/, "", id); cur = id; next
        }
        /^plugin=org\.kde\.plasma\.kickoff$/ { print cur }
      ' "$APPLETSRC")
      ORDER=$(printf '%s\n' "$REFS" | $PASTE -sd, -)
      for id in $IDS; do
        $KWRITECONFIG --file kactivitymanagerd-statsrc \
          --group "Favorites-org.kde.plasma.kickoff.favorites.instance-''${id}-global" \
          --key ordering "$ORDER"
      done
      if [ -f "$STATSRC" ]; then
        IDS_LIST=" $(printf '%s' "$IDS" | tr '\n' ' ') "
        $SED -n 's/^\[\(Favorites-org\.kde\.plasma\.kickoff\.favorites\.instance-\([0-9]\+\)-.*\)\]$/\2\t\1/p' "$STATSRC" \
          | while IFS="$(printf '\t')" read -r sid group; do
              case "$IDS_LIST" in
                *" $sid "*) ;;
                *) $KWRITECONFIG --file kactivitymanagerd-statsrc --group "$group" --key ordering --delete ;;
              esac
            done
      fi
    fi
  '';
in
{
  options.programs.plasma.kickoff.favorites = lib.mkOption {
    type = with lib.types; nullOr (listOf str);
    default = null;
    example = [
      "firefox"
      "io.github.martinrotter.rssguard.desktop"
      "preferred://browser"
    ];
    description = "Applications to pin as favorites in Kickoff.";
  };
  config = lib.mkIf (cfg.enable && cfg.kickoff.favorites != null) {
    programs.plasma.startup.startupScript."kickoff_favorites" = {
      runAlways = true;
      priority = 3;
      text = "${script}";
    };
  };
}
