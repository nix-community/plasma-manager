import configparser
import json
import os
import re
import sys
from typing import Dict


class KConfParser:
    def __init__(self, filepath):
        self.data = {}
        self.filepath = filepath
        self.read()

    def read(self):
        """Read the config from the path specified on instantiation. If the
        path doesn't exist, do nothing"""
        try:
            with open(self.filepath, "r") as f:
                current_group = 0
                for l in f:
                    # Checks if the current line indicates a group.
                    if re.match(r"^\[.*\]\s*$", l):
                        current_group = l.rstrip().lstrip("[").rstrip("]")
                        self.data[current_group] = {}
                        continue

                    # Empty lines we won't bother reading.
                    if l.strip() != "":
                        key, value = self.get_key_value(l)
                        self.set_value(current_group, key, value)
        except FileNotFoundError:
            pass

    def set_value(self, group, key, value):
        """Adds an entry to the config. Creates necessary groups if needed."""
        if not group in self.data:
            self.data[group] = {}
        self.data[group][key] = value

    def remove_value(self, group, key):
        """Removes an entry from the config. Does nothing if the entry isn't there."""
        if group in self.data and key in self.data[group]:
            del self.data[group][key]
            # We remove the group altogether if there are no keys in the group
            # anymore.
            if not self.data[group]:
                del self.data[group]

    def save(self):
        """Save to the filepath specified on instantiation."""
        # If the directory we want to save to doesn't exist we will allow this,
        # and just create the directory before.
        dir = os.path.dirname(self.filepath)
        if not os.path.exists(dir):
            os.mkdir(dir)

        with open(self.filepath, "w") as f:
            # We skip a newline before the first category
            skip_newline = True

            for group in self.data:
                if group == 0:
                    skip_newline = False
                    for key, value in self.data[0].items():
                        f.write(f"{self.key_value_to_line(key, value)}\n")
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
    def get_key_value(line: str) -> tuple[str, str]:
        line_splitted = line.split("=", 1)
        key = line_splitted[0].strip()
        value = line_splitted[1].strip() if len(line_splitted) > 1 else None
        return key, value

    @staticmethod
    def key_value_to_line(key: str, value: str) -> str:
        """For keys with values (not None) we give key=value, if not just give
        the key as the line (this is useful in khotkeysrc)."""
        return f"{key}={value}" if not value is None else key


def write_config_single(filepath: str, items: Dict):
    config = KConfParser(filepath)

    for entry in items.values():
        group = f"{']['.join(entry['configGroupNesting'])}"

        for key, value in entry.items():
            if key == "configGroupNesting":
                continue

            # If the nix expression is null, resulting in the value None here,
            # we remove the key/option (and the group/section if it is empty
            # after removal).
            if value is None:
                config.remove_value(group, key)
                continue

            # Convert value to string.
            value = str(value) if not isinstance(value, bool) else str(value).lower()

            config.set_value(group, key, value)

    config.save()


def write_configs(d: Dict):
    for filepath, c in d.items():
        write_config_single(filepath, c)


def main():
    if len(sys.argv) != 2:
        raise ValueError(f"Must receive exactly one argument, got: {len(sys.argv) - 1}")

    d = json.loads(sys.argv[1])
    write_configs(d)


if __name__ == "__main__":
    main()
