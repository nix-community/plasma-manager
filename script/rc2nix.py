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
from typing import Callable, Dict, List, Optional, Tuple

# The root directory where configuration files are stored.
XDG_CONFIG_HOME: str = os.path.expanduser(os.getenv("XDG_CONFIG_HOME", "~/.config"))
XDG_DATA_HOME: str = os.path.expanduser(os.getenv("XDG_DATA_HOME", "~/.local/share"))


class Rc2Nix:
    # Files that we'll scan by default.
    KNOWN_CONFIG_FILES: List[str] = [
        os.path.join(XDG_CONFIG_HOME, f)
        for f in [
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
            "ktrashrc",
            "kuriikwsfilterrc",
            "plasmaparc",
            "spectaclerc",
            "katerc",
        ]
    ]
    KNOWN_DATA_FILES: List[str] = [
        os.path.join(XDG_DATA_HOME, f)
        for f in [
            "kate/anonymous.katesession",
            "dolphin/view_properties/global/.directory",
        ]
    ]

    class RcFile:
        # Any group that matches a listed regular expression is blocked
        GROUP_BLOCK_LIST: List[str] = [
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
            r"^Recent (Files|URLs)",
        ]

        # Similar to the GROUP_BLOCK_LIST but for setting keys.
        KEY_BLOCK_LIST: List[str] = [
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

        # List of functions that get called with a group name and a key name.
        BLOCK_LIST_LAMBDA: List[Callable[[str, str], bool]] = [
            lambda group, key: group == "org.kde.kdecoration2" and key == "library"
        ]

        def __init__(self, file_name: str):
            self.file_name: str = file_name
            self.settings: Dict[str, Dict[str, str]] = {}
            self.last_group: Optional[str] = None

        def parse(self):

            def is_group_line(line: str) -> bool:
                return re.match(r"^\s*(\[[^\]]+\])+\s*$", line) is not None

            def is_setting_line(line: str) -> bool:
                return re.match(r"^\s*([^=]+)=?(.*)\s*$", line) is not None

            def parse_group(line: str) -> str:
                return re.sub(
                    r"\s*\[([^\]]+)\]\s*", r"\1/", line.replace("/", "\\\\/")
                ).rstrip("/")

            def parse_setting(line: str) -> Tuple[str, str]:
                match = re.match(r"^\s*([^=]+)=?(.*)\s*$", line)
                if match:
                    return match.groups()  # type: ignore
                raise Exception(f"{self.file_name}: can't parse setting line: {line}")

            with open(self.file_name, "r") as file:
                for line in file:
                    line = line.strip()
                    if not line:
                        continue
                    if is_group_line(line):
                        self.last_group = parse_group(line)
                    elif is_setting_line(line):
                        key, val = parse_setting(line)
                        self.process_setting(key, val)
                    else:
                        raise Exception(f"{self.file_name}: can't parse line: {line}")

        def process_setting(self, key: str, val: str):

            def should_skip_group(group: str) -> bool:
                return any(re.match(reg, group) for reg in self.GROUP_BLOCK_LIST)

            def should_skip_key(key: str) -> bool:
                return any(re.match(reg, key) for reg in self.KEY_BLOCK_LIST)

            def should_skip_by_lambda(group: str, key: str) -> bool:
                return any(fn(group, key) for fn in self.BLOCK_LIST_LAMBDA)

            key = key.strip()
            val = val.strip()

            if self.last_group is None:
                raise Exception(
                    f"{self.file_name}: setting outside of group: {key}={val}"
                )

            if (
                should_skip_group(self.last_group)
                or should_skip_key(key)
                or should_skip_by_lambda(self.last_group, key)
            ):
                return

            if self.last_group not in self.settings:
                self.settings[self.last_group] = {}
            self.settings[self.last_group][key] = val

    class App:
        def __init__(self, args: List[str]):
            self.config_files: List[str] = Rc2Nix.KNOWN_CONFIG_FILES.copy()
            self.data_files: List[str] = Rc2Nix.KNOWN_DATA_FILES.copy()
            self.config_settings: Dict[str, Dict[str, Dict[str, str]]] = {}
            self.data_settings: Dict[str, Dict[str, Dict[str, str]]] = {}

        def run(self):
            for file in self.config_files:
                if not os.path.exists(file):
                    continue

                rc = Rc2Nix.RcFile(file)
                rc.parse()

                path = Path(file).relative_to(XDG_CONFIG_HOME)
                self.config_settings[str(path)] = rc.settings

            for file in self.data_files:
                if not os.path.exists(file):
                    continue

                rc = Rc2Nix.RcFile(file)
                rc.parse()

                path = Path(file).relative_to(XDG_DATA_HOME)
                self.data_settings[str(path)] = rc.settings

            self.print_output()

        def print_output(self):
            print("{")
            print("  programs.plasma = {")
            print("    enable = true;")
            print("    shortcuts = {")
            print(
                self.pp_shortcuts(self.config_settings.get("kglobalshortcutsrc", {}), 6)
            )
            print("    };")
            print("    configFile = {")
            print(self.pp_settings(self.config_settings, 6))
            print("    };")
            print("    dataFile = {")
            print(self.pp_settings(self.data_settings, 6))
            print("    };")
            print("  };")
            print("}")

        def pp_settings(
            self, settings: Dict[str, Dict[str, Dict[str, str]]], indent: int
        ) -> str:
            result: List[str] = []
            for file in sorted(settings.keys()):
                if file != "kglobalshortcutsrc":
                    for group in sorted(settings[file].keys()):
                        for key in sorted(settings[file][group].keys()):
                            if key != "_k_friendly_name":
                                result.append(
                                    f"{' ' * indent}\"{file}\".\"{group}\".\"{key}\" = {nix_val(settings[file][group][key])};"
                                )
            return "\n".join(result)

        def pp_shortcuts(self, groups: Dict[str, Dict[str, str]], indent: int) -> str:
            if not groups:
                return ""

            result: List[str] = []
            for group in sorted(groups.keys()):
                for action in sorted(groups[group].keys()):
                    if action != "_k_friendly_name":
                        keys = (
                            groups[group][action]
                            .split(r"(?<!\\),")[0]
                            .replace(r"\?", ",")
                            .replace(r"\t", "\t")
                            .split("\t")
                        )

                        if not keys or keys[0] == "none":
                            keys_str = "[ ]"
                        elif len(keys) > 1:
                            keys_str = (
                                f"[{' '.join(nix_val(k.rstrip(',')) for k in keys)}]"
                            )
                        else:
                            ks = keys[0].split(",")
                            k = ks[0] if len(ks) == 3 and ks[0] == ks[1] else keys[0]
                            keys_str = (
                                "[ ]"
                                if k == "" or k == "none"
                                else nix_val(k.rstrip(","))
                            )

                        result.append(
                            f"{' ' * indent}\"{group}\".\"{action}\" = {keys_str};"
                        )
            return "\n".join(result)


def nix_val(s: Optional[str]) -> str:
    if s is None:
        return "null"
    if re.match(r"^(true|false)$", s, re.IGNORECASE):
        return s.lower()
    if re.match(r"^[0-9]+(\.[0-9]+)?$", s):
        return s
    return '"' + re.sub(r'(?<!\\)"', r'\\"', s) + '"'


Rc2Nix.App(sys.argv[1:]).run()
