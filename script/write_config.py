import glob
import json
import os
import re
import sys
from typing import Dict, Optional, Set


class KConfManager:
    def __init__(self, filepath: str, json_dict: Dict, override_config: bool):
        self.data = {}
        self.json_dict = json_dict
        self.filepath = filepath
        self.override_config = override_config
        self._json_value_checks()

    def _json_value_checks(self):
        for group, entry in self.json_dict.items():
            for key, value in entry.items():
                # We don't allow persistency when not using overrideConfig
                if value["persistent"] and not self.override_config:
                    raise Exception(
                        f'Plasma-manager: Persistency enabled for key "{key}" in group "{group}" when overrideConfig is disabled. '
                        "Persistency without using overrideConfig is not supported"
                    )
                elif value["persistent"] and value["value"] is not None:
                    raise Exception(
                        f"Plasma-manager: Persistency enabled for key \"{key}\" in group \"{group}\" with value {value['value']}. "
                        "A value cannot be given when persistency is enabled"
                    )

    def key_is_persistent(self, group, key) -> bool:
        """
        Checks if a key in a group in the nix config is persistent.
        """
        try:
            is_persistent = (
                self.json_dict[group][key]["persistent"]
                and self.json_dict[group][key]["value"] is None
            )
        except KeyError:
            is_persistent = False

        return is_persistent

    def read(self):
        """
        Read the config from the path specified on instantiation. If the
        path doesn't exist, do nothing.
        """
        try:
            with open(self.filepath, "r", encoding="utf-8") as f:
                current_group = 0
                for l in f:
                    # Checks if the current line indicates a group.
                    if re.match(r"^\[.*\]\s*$", l):
                        current_group = l.rstrip().lstrip("[").rstrip("]")
                        self.data[current_group] = {}
                        continue

                    # We won't bother reading empty lines.
                    if l.strip() != "":
                        key, value = self.get_key_value(l)

                        # We only read the current key if overrideConfig is
                        # disabled or the value is marked as persistent in the
                        # plasma-manager config.
                        is_persistent = self.key_is_persistent(current_group, key)
                        if not self.override_config or is_persistent:
                            self.set_value(
                                current_group,
                                key,
                                {
                                    "value": value,
                                    "immutable": False,
                                    "shellExpand": False,
                                    "persistent": is_persistent,
                                },
                            )
        except FileNotFoundError:
            pass

    def run(self):
        self.read()
        for group, entry in self.json_dict.items():
            # The nix expressions will have / to separate groups. We replace this by
            # ][ which is needed for the kde config files. If the / is escaped, it
            # will simply be replaced by a normal /.
            group = re.sub(r"(?<!\\)/", "][", group)
            group = group.replace("\\/", "/")
            for key, value in entry.items():
                # If the nix expression is null, resulting in the value None here,
                # we remove the key/option (and the group/section if it is empty
                # after removal, and persistency is disabled).
                if value["value"] is None and not value["persistent"]:
                    self.remove_value(group, key)
                    continue

                # Again values from the nix json are not escaped, so we need to
                # escape them here (in case it includes \t \n and so on). We
                # also don't set the keys if the key is persistent, as we want
                # to leave that key unchanged from the read() method.
                if not value["persistent"]:
                    self.set_value(group, key, value, escape_value=True)

    def set_value(self, group, key, value, escape_value=False):
        """Adds an entry to the config. Creates necessary groups if needed."""
        if not group in self.data:
            self.data[group] = {}

        # The value of the key
        key_value = (
            str(value["value"])
            if not isinstance(value["value"], bool)
            else str(value["value"]).lower()
        )
        # Whether we have immutability
        key_immutable = value["immutable"]
        # Whether we have shell-expansion for the key
        key_shellexpand = value["shellExpand"]

        # We need to add the app
        key += self.calculate_marking(key_immutable, key_shellexpand)

        # Escapes symbols like \t, \n and so on if escape_value is True. This
        # should be true when reading from the nix json, but not when reading
        # from file (as reading from a file that is already escaped).
        if escape_value:
            to_escape = ["\t", "\n"]
            # value = value.encode("unicode_escape").decode()
            for escape_char in to_escape:
                key_value = key_value.replace(
                    escape_char, escape_char.encode("unicode_escape").decode()
                )

        self.data[group][key] = key_value

    def remove_value(self, group, key):
        """Removes an entry from the config. Does nothing if the entry isn't there."""
        if group in self.data and key in self.data[group]:
            del self.data[group][key]

    def save(self):
        """Save to the filepath specified on instantiation."""
        # If the directory we want to save to doesn't exist we will allow this,
        # and just create the directory before.
        dir = os.path.dirname(self.filepath)
        if not os.path.exists(dir):
            os.makedirs(dir)

        with open(self.filepath, "w", encoding="utf-8") as f:
            # We skip a newline before the first category
            skip_newline = True

            for group in self.data:
                if group == 0:
                    skip_newline = False
                    for key, value in self.data[0].items():
                        f.write(f"{self.key_value_to_line(key, value)}\n")
                    continue
                elif not self.data[group]:
                    # We skip over groups with no keys, they don't need to be written
                    continue

                if not skip_newline:
                    f.write("\n")
                else:
                    # Only skip the newline once of course.
                    skip_newline = False

                f.write(f"[{group}]\n")
                for key, value in self.data[group].items():
                    f.write(f"{self.key_value_to_line(key, value)}\n")

    @staticmethod
    def get_key_value(line: str) -> tuple[str, Optional[str]]:
        line_splitted = line.split("=", 1)
        key = line_splitted[0].strip()
        value = line_splitted[1].strip() if len(line_splitted) > 1 else None
        return key, value

    @staticmethod
    def key_value_to_line(key: str, value: str) -> str:
        """For keys with values (not None) we give key=value, if not just give
        the key as the line (this is useful in khotkeysrc)."""
        return f"{key}={value}" if not value is None else key

    @staticmethod
    def calculate_marking(immutable, expandvars):
        """
        Calculates the "marking" we should add to the keys, which for example may be
        [$i] if we want immutability, or [$e] if we want to expand variables. See
        https://api.kde.org/frameworks/kconfig/html/options.html for some options.
        """
        if immutable and expandvars:
            return "[$ei]"
        elif immutable:
            return "[$i]"
        elif expandvars:
            return "[$e]"
        else:
            return ""


def remove_config_files(d: Dict, reset_files: Set):
    """
    Removes files which doesn't have any configuration entries in d and which is
    in the list of files to be reset by overrideConfig.
    """
    for del_path in reset_files - set(d.keys()):
        for file_to_del in glob.glob(del_path):
            if os.path.isfile(file_to_del):
                os.remove(file_to_del)


def write_configs(d: Dict, override_config: bool):
    for filepath, c in d.items():
        config = KConfManager(filepath, c, override_config)
        config.run()
        config.save()


def main():
    if len(sys.argv) != 4:
        raise ValueError(
            f"Must receive exactly three arguments, got: {len(sys.argv) - 1}"
        )

    json_path = sys.argv[1]
    with open(json_path, "r") as f:
        json_str = f.read()

    # We send in "true" as the second argument if overrideConfig is enabled in
    # plasma-manager.
    override_config = bool(sys.argv[2])
    # os.system(f"echo '{sys.argv[2]}' > /home/user1/Downloads/test")
    # The files to be reset when we have overrideConfig enabled.
    oc_reset_files = set(sys.argv[3].split(" "))

    d = json.loads(json_str)
    # If overrideConfig is enabled we delete all the kde config files which are
    # not configured through plasma-manager.
    if override_config:
        remove_config_files(d, oc_reset_files)
    write_configs(d, override_config)


if __name__ == "__main__":
    main()
