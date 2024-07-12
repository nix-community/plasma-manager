#!/usr/bin/env python3
import unittest
import subprocess
import os

def red(s: str) -> str:
    return '\033[91m' + s + '\033[0m'

def green(s: str) -> str:
    return '\033[32m' + s + '\033[0m'

def gray(s: str) -> str:
    return '\033[90m' + s + '\033[0m'

current_dir = os.path.dirname(os.path.abspath(__file__))
def path(relative_path: str) -> str:
    return os.path.abspath(os.path.join(current_dir, relative_path))

script_path = path("../../script/rc2nix.py")

class TestRc2nix (unittest.TestCase):

    def test(self):
        result = subprocess.run([script_path], check=True, env={'XDG_CONFIG_HOME': path('./test_data')}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(red(result.stdout))
        result.check_returncode()
        print(result.stderr)

if __name__ == '__main__': # pragma: no cover
    _ = unittest.main()
