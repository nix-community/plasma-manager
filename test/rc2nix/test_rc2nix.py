#!/usr/bin/env nix
#! nix shell nixpkgs#python3Packages.python nixpkgs#ruby -c python3
import os
import subprocess
import unittest


def red(s: str) -> str:
    return "\033[91m" + s + "\033[0m"


def green(s: str) -> str:
    return "\033[32m" + s + "\033[0m"


def gray(s: str) -> str:
    return "\033[90m" + s + "\033[0m"


current_dir = os.path.dirname(os.path.abspath(__file__))


def path(relative_path: str) -> str:
    return os.path.abspath(os.path.join(current_dir, relative_path))


rc2nix_py = path("../../script/rc2nix.py")
rc2nix_rb = path("../../script/rc2nix.rb")


class TestRc2nix(unittest.TestCase):

    def test(self):
        def run_script(*command: str) -> str:
            rst = subprocess.run(
                command,
                env={
                    "XDG_CONFIG_HOME": path("./test_data"),
                    "PATH": os.environ["PATH"],
                },
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            print(red(rst.stderr))
            rst.check_returncode()
            return rst.stdout

        rst_py = run_script(rc2nix_py)
        rst_rb = run_script(rc2nix_rb)

        self.assertEqual(rst_py.splitlines(), rst_rb.splitlines())


if __name__ == "__main__":  # pragma: no cover
    _ = unittest.main()
