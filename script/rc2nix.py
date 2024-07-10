#!/usr/bin/env python

################################################################################
#
# This file is part of the package Plasma Manager.  It is subject to
# the license terms in the LICENSE file found in the top-level
# directory of this distribution and at:
#
#   https://github.com/nix-community/plasma-manager
#
# No part of this package, including this file, may be copied,
# modified, propagated, or distributed except according to the terms
# contained in the LICENSE file.
#
################################################################################

import os
import re
import sys
from pathlib import Path

############################################################################
# The root directory where configuration files are stored.
XDG_CONFIG_HOME = os.path.expanduser(os.getenv("XDG_CONFIG_HOME", "~/.config"))

################################################################################
class Rc2Nix:

    ############################################################################
    # Files that we'll scan by default.
    KNOWN_FILES = [
        "kcminputrc",
        "kglobalshortcutsrc",
        "kactivitymanagerdrc",
        "ksplashrc",
        "kwin_rules_dialogrc",
        "kmixrc",
        "kwalletrc",
        "kgammarc",
        "krunnerrc",
        "klaunchrc",
        "plasmanotifyrc",
        "systemsettingsrc",
        "kscreenlockerrc",
        "kwinrulesrc",
        "khotkeysrc",
        "ksmserverrc",
        "kded5rc",
        "plasmarc",
        "kwinrc",
        "kdeglobals",
        "baloofilerc",
        "dolphinrc",
        "klipperrc",
        "plasma-localerc",
        "kxkbrc",
        "ffmpegthumbsrc",
        "kservicemenurc",
        "kiorc",
    ]
    KNOWN_FILES = [os.path.join(XDG_CONFIG_HOME, f) for f in KNOWN_FILES]

    ############################################################################
    class RcFile:

        ########################################################################
        # Any group that matches a listed regular expression is blocked
        # from being passed through to the settings attribute.
        GROUP_BLOCK_LIST = [
            r"^(ConfigDialog|FileDialogSize|ViewPropertiesDialog|KPropertiesDialog)$",
            r"^\$Version$",
            r"^ColorEffects:",
            r"^Colors:",
            r"^DoNotDisturb$",
            r"^LegacySession:",
            r"^MainWindow$",
            r"^PlasmaViews",
            r"^ScreenConnectors$",
            r"^Session:",
        ]

        ########################################################################
        # Similar to the GROUP_BLOCK_LIST but for setting keys.
        KEY_BLOCK_LIST = [
            r"^activate widget \d+$",  # Depends on state :(
            r"^ColorScheme(Hash)?$",
            r"^History Items",
            r"^LookAndFeelPackage$",
            r"^Recent (Files|URLs)",
            r"^Theme$i",
            r"^Version$",
            r"State$",
            r"Timestamp$",
        ]

        ########################################################################
        # List of functions that get called with a group name and a key
        # name.  If the function returns +true+ then block that key.
        BLOCK_LIST_LAMBDA = [
            lambda group, key: group == "org.kde.kdecoration2" and key == "library"
        ]

        ########################################################################
        def __init__(self, file_name):
            self.file_name = file_name
            self.settings = {}
            self.last_group = None

        ########################################################################
        def parse(self):
            with open(self.file_name, 'r') as file:
                for line in file:
                    line = line.strip()
                    if not line:
                        continue
                    if re.match(r'^\s*(\[[^\]]+\]){1,}\s*$', line):
                        self.last_group = self.parse_group(line)
                    elif re.match(r'^\s*([^=]+)=?(.*)\s*$', line):
                        key, val = re.match(r'^\s*([^=]+)=?(.*)\s*$', line).groups()
                        key = key.strip()
                        val = val.strip()

                        if self.last_group is None:
                            raise Exception(f"{self.file_name}: setting outside of group: {line}")

                        # Reasons to skip this group or key:
                        if any(re.match(reg, self.last_group) for reg in self.GROUP_BLOCK_LIST):
                            continue
                        if any(re.match(reg, key) for reg in self.KEY_BLOCK_LIST):
                            continue
                        if any(fn(self.last_group, key) for fn in self.BLOCK_LIST_LAMBDA):
                            continue
                        if os.path.basename(self.file_name) == "plasmanotifyrc" and key == "Seen":
                            continue

                        if self.last_group not in self.settings:
                            self.settings[self.last_group] = {}
                        self.settings[self.last_group][key] = val
                    else:
                        raise Exception(f"{self.file_name}: can't parse line: {line}")

        ########################################################################
        def parse_group(self, line):
            return re.sub(r'\s*\[([^\]]+)\]\s*', r'\1/', line.replace("/", "\\/")).rstrip("/")

    ############################################################################
    class App:

        ########################################################################
        def __init__(self, args):
            self.files = Rc2Nix.KNOWN_FILES.copy()

        ########################################################################
        def run(self):
            settings = {}

            for file in self.files:
                if not os.path.exists(file):
                    continue

                rc = Rc2Nix.RcFile(file)
                rc.parse()

                path = Path(file).relative_to(XDG_CONFIG_HOME)
                settings[str(path)] = rc.settings

            print("{")
            print("  programs.plasma = {")
            print("    enable = true;")
            print("    shortcuts = {")
            self.pp_shortcuts(settings.get("kglobalshortcutsrc", {}), 6)
            print("    };")
            print("    configFile = {")
            self.pp_settings(settings, 6)
            print("    };")
            print("  };")
            print("}")

        ########################################################################
        def pp_settings(self, settings, indent):
            for file in sorted(settings.keys()):
                for group in sorted(settings[file].keys()):
                    for key in sorted(settings[file][group].keys()):
                        if file == "kglobalshortcutsrc" and key != "_k_friendly_name":
                            continue

                        print(" " * indent, end="")
                        print(f"\"{file}\".", end="")
                        print(f"\"{group}\".", end="")
                        print(f"\"{key}\" = ", end="")
                        print(self.nix_val(settings[file][group][key]), end="")
                        print(";")

        ########################################################################
        def pp_shortcuts(self, groups, indent):
            if not groups:
                return

            for group in sorted(groups.keys()):
                for action in sorted(groups[group].keys()):
                    if action == "_k_friendly_name":
                        continue

                    print(" " * indent, end="")
                    print(f"\"{group}\".", end="")
                    print(f"\"{action}\" = ", end="")

                    keys = groups[group][action].split(r'(?<!\\),')[0].replace(r'\?', ',').replace(r'\t', '\t').split('\t')

                    if not keys:
                        print("[ ]", end="")
                    elif len(keys) > 1:
                        print("[", end="")
                        print(" ".join(self.nix_val(k) for k in keys), end="")
                        print("]", end="")
                    elif keys[0] == "none":
                        print("[ ]", end="")
                    else:
                        print(self.nix_val(keys[0]), end="")

                    print(";")

        ########################################################################
        def nix_val(self, str):
            if str is None:
                return "null"
            if re.match(r'^true|false$', str, re.IGNORECASE):
                return str.lower()
            if re.match(r'^[0-9]+(\.[0-9]+)?$', str):
                return str
            return '"' + str.replace('"', '\\"') + '"'

################################################################################
Rc2Nix.App(sys.argv[1:]).run()
