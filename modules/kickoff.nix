{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.plasma;

  favoritesLines = pkgs.writeText "kickoff-favorites-lines" (
    (lib.concatStringsSep "\n" (lib.unique cfg.kickoff.favorites)) + "\n"
  );

  # the escaped ordering list as a single csv line as read in the config
  favoritesCsv = pkgs.writeText "kickoff-favorites-csv" (
    (lib.concatStringsSep "," (
      # kconfig escapes backslashes as `\\` and commas as `\,`
      # the config writer doubles backslashes, so we have to write `\\\\` and `\\,`
      lib.map (lib.replaceStrings [ "\\" "," ] [ "\\\\\\\\" "\\\\," ]) (lib.unique cfg.kickoff.favorites)
    ))
    + "\n"
  );

  qdbus = "${pkgs.kdePackages.qttools}/bin/qdbus";
  sqlite3 = "${pkgs.sqlite}/bin/sqlite3";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  agent = "org.kde.plasma.favorites.applications";
  activity = ":global";
  service = "org.kde.ActivityManager";
  object = "/ActivityManager/Resources/Linking";
  iface = "org.kde.ActivityManager.ResourcesLinking";
  # sql escape for sed
  sqEscape = "s/'/''/g";

  ##############################################################################
  # Reconcile the pinned set of favorites and ordering before anything has read them.
  syncScript = pkgs.writeShellScript "kickoff-favorites-sync" ''
    set -euo pipefail

    db="${config.xdg.dataHome}/kactivitymanagerd/resources/database"
    appletsrc="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"
    statsrc="${config.xdg.configHome}/kactivitymanagerd-statsrc"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    # reconcile ResourceLink rows directly in the database
    # kactivitymanagerd is not running yet, so nothing is using the database
    if [ -f "$db" ]; then
      existing="$tmp/existing"
      # read the existing resource links to our temp file
      "${sqlite3}" -readonly "$db" \
        "SELECT targettedResource FROM ResourceLink WHERE initiatingAgent = '${agent}' AND usedActivity = '${activity}';" \
        > "$existing" 2>/dev/null || : > "$existing"
      {
        echo "BEGIN TRANSACTION;"
        # delete links that are no longer pinned
        while IFS= read -r res; do
          [ -n "$res" ] || continue
          grep -Fqx "$res" "${favoritesLines}" || printf \
            "DELETE FROM ResourceLink WHERE usedActivity = '${activity}' AND initiatingAgent = '${agent}' AND targettedResource = '%s';\n" \
            "$(printf '%s' "$res" | sed "${sqEscape}")"
        done < "$existing"
        # add new pinned links
        while IFS= read -r res; do
          [ -n "$res" ] || continue
          grep -Fqx "$res" "$existing" || printf \
            "INSERT OR IGNORE INTO ResourceLink (usedActivity, initiatingAgent, targettedResource) VALUES ('${activity}', '${agent}', '%s');\n" \
            "$(printf '%s' "$res" | sed "${sqEscape}")"
        done < "${favoritesLines}"
        echo "COMMIT;"
      } | "${sqlite3}" "$db" >/dev/null
    fi

    # get the active kickoff applet numeric IDs from the appletsrc
    kickoffIDs="$tmp/ids"
    if [ -f "$appletsrc" ]; then
      awk '
        match($0, /\[Applets\]\[([0-9]+)\]$/, m) { id = m[1] }
        /^plugin=org\.kde\.plasma\.kickoff$/ { print id }
      ' "$appletsrc" | sort -u > "$kickoffIDs"
    else
      : > "$kickoffIDs"
    fi

    # rewrite the ordering of every favorites group
    # drops groups whose instance id no longer exists in the panel layout
    # skipped when the layout is unreadable/empty, so a fresh profile writes nothing
    #
    # if panel configuration is changed such that applet IDs change,
    # the new ordering will take effect after a second login,
    # since kde configuration is written AFTER this script runs
    # kde defaults to lexicographically sorting entries by URI
    #
    # ordering of ALL kickoff instances is changed since determining which
    # instance belongs to which ID is a bit out of scope..
    statsrc_new="$tmp/statsrc_new"
    if [ -f "$statsrc" ]; then
      # pass files and set prune to skip if the IDs file is empty
      awk -v csvfile="${favoritesCsv}" -v idsfile="$kickoffIDs" \
        -v prune="$([ -s "$kickoffIDs" ] || echo skip)" '
        BEGIN {
          printing = 1
          # read active applet IDs into a map
          while ((getline line < idsfile) > 0) if (line != "") active[line] = 1
          close(idsfile)
          # read the escaped ordering csv file
          getline csv < csvfile
          close(csvfile)
        }
        # match favorites headers
        /^\[Favorites-org\.kde\.plasma\.kickoff\.favorites\.instance-/ {
          group = $0
          id = group
          # extract applet ID from the group title
          sub(/^\[Favorites-org\.kde\.plasma\.kickoff\.favorites\.instance-/, "", id)
          if (match(id, /^[0-9]+/)) id = substr(id, 1, RLENGTH); else id = ""
          # keep this section if we arent pruning or the applet is still active
          keep = (prune == "skip") || (id in active)
          printing = keep
          if (keep) print group
          next
        }
        # pass through any other headers
        /^\[/ { printing = 1 }
        # rewrite ordering if we are under a header that gets changed
        printing && /^ordering=/ { print "ordering=" csv; next }
        printing { print }
      ' "$statsrc" > "$statsrc_new"
    else
      : > "$statsrc_new"
    fi
    # add the global group for every active instance that doesn't have one yet
    favorites_csv="$(cat "${favoritesCsv}")"
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      group="Favorites-org.kde.plasma.kickoff.favorites.instance-''${id}-global"
      grep -Fqx "[''${group}]" "$statsrc_new" \
        || printf '\n[%s]\nordering=%s\n' "$group" "$favorites_csv" >> "$statsrc_new"
    done < "$kickoffIDs"

    # apply new file if it differs
    if [ -f "$statsrc" ] || [ -s "$statsrc_new" ]; then
      if ! cmp -s "$statsrc" "$statsrc_new"; then
        mkdir -p "$(dirname "$statsrc")"
        cp "$statsrc_new" "$statsrc"
      fi
    fi
  '';

  ##############################################################################
  # Fallback script for fresh plasma profiles.
  # the database only exists once kactivitymanagerd first ran,
  # so the pre-login reconcile above cant write links
  fallbackScript = pkgs.writeShellScript "kickoff-favorites-fallback" ''
    set -euo pipefail

    db="${config.xdg.dataHome}/kactivitymanagerd/resources/database"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    # read existing resource links from db
    existing="$tmp/existing"
    if [ -f "$db" ]; then
      "${sqlite3}" -readonly "$db" \
        "SELECT targettedResource FROM ResourceLink WHERE initiatingAgent = '${agent}' AND usedActivity = '${activity}';" \
        > "$existing" 2>/dev/null || : > "$existing"
    else
      : > "$existing"
    fi

    # ensure the existing db entries and pinned lines are not out of sync
    need_change=0
    while IFS= read -r res; do
      [ -n "$res" ] || continue
      grep -Fqx "$res" "$existing" || need_change=1
    done < "${favoritesLines}"
    while IFS= read -r res; do
      [ -n "$res" ] || continue
      grep -Fqx "$res" "${favoritesLines}" || need_change=1
    done < "$existing"
    [ "$need_change" -eq 1 ] || exit 0

    # wait for the activitymanager session service to come up
    i=0
    until "${qdbus}" "${service}" "${object}" >/dev/null 2>&1; do
      i=$((i + 1))
      [ "$i" -ge 180 ] && break
      sleep 0.5
    done
    if "${qdbus}" "${service}" "${object}" >/dev/null 2>&1; then
      # reconcile links over dbus
      while IFS= read -r res; do
        [ -n "$res" ] || continue
        grep -Fqx "$res" "$existing" \
          || "${qdbus}" "${service}" "${object}" "${iface}.LinkResourceToActivity" "${agent}" "$res" "${activity}"
      done < "${favoritesLines}"
      while IFS= read -r res; do
        [ -n "$res" ] || continue
        grep -Fqx "$res" "${favoritesLines}" \
          || "${qdbus}" "${service}" "${object}" "${iface}.UnlinkResourceFromActivity" "${agent}" "$res" "${activity}"
      done < "$existing"
      # plasmashell needs restarted to see the new links
      "${systemctl}" --user restart plasma-plasmashell
    else
      echo "kactivitymanagerd dbus not available, skipping favorites link reconcile." >&2
    fi
  '';
in
{
  options.programs.plasma.kickoff.favorites = lib.mkOption {
    type = with lib.types; nullOr (listOf str);
    default = null;
    example = [
      "applications:org.kde.konsole.desktop"
      "applications:org.kde.dolphin.desktop"
      "preferred://browser"
    ];
    description = ''
      List of kickoff favorites, in order.
      Supported values are menu IDs (usually .desktop file names),
      special URLs that expand into default applications (e.g. preferred://browser),
      document URLs and KPeople contact URIs.

      This list is written to every kickoff instance before plasmashell starts.
      In the event that panel configuration changes, entries may default to
      lexicographical sorting by URI until next login.
      ~/.config/plasma-org.kde.plasma.desktop-appletsrc must be available
      during login for ordering to be written correctly.

      Entries are written verbatim as the resource strings tracked by kactivitymanagerd,
      so menu IDs should use the full `applications:<menu-id>.desktop` form.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.kickoff.favorites != null) {
    systemd.user.services.kickoff-favorites = {
      Unit = {
        Description = "Reconcile declarative Kickoff favorites";
        After = [ "basic.target" ];
        # Must run before kactivitymanagerd/plasmashell open the database.
        Before = [
          "plasma-kactivitymanagerd.service"
          "plasma-plasmashell.service"
          "graphical-session.target"
        ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
      };
      Install = {
        WantedBy = [ "plasma-core.target" ];
      };
    };

    # fallback post-login dbus script
    programs.plasma.startup.startupScript."kickoff_favorites" = {
      priority = 3;
      text = "${fallbackScript}";
    };
  };
}
