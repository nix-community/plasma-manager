import configparser
import json
import sys
from typing import Dict


def write_config_single(filename: str, items: Dict):
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    config.read(filename)

    for entry in items.values():
        group = f"{']['.join(entry['configGroupNesting'])}"
        if not group in config:
            config.add_section(group)

        for key, value in entry.items():
            if key == "configGroupNesting":
                continue

            # If the nix expression is null, resulting in the value None here,
            # we remove the key/option (and the group/section if it is empty
            # after removal).
            if value is None:
                if key in config[group]:
                    config.remove_option(group, key)
                if not config[group]:
                    config.remove_section(group)
                continue

            # Convert value to string.
            value = str(value) if not isinstance(value, bool) else str(value).lower()

            config[group][key] = value

    with open(filename, "w") as f:
        config.write(f, space_around_delimiters=False)


def write_configs(d: Dict):
    for filename, c in d.items():
        write_config_single(filename, c)


def main():
    if len(sys.argv) != 2:
        raise ValueError(f"Must receive exactly one argument, got: {len(sys.argv) - 1}")

    d = json.loads(sys.argv[1])
    write_configs(d)


if __name__ == "__main__":
    main()
