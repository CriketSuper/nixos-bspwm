"""Boundary tests for the installer settings passed into NixOS modules."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("installer_settings", ROOT / "scripts" / "render-settings.py")
SETTINGS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SETTINGS)


class InstallerSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def options(self, data):
        path = self.root / "options.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return SETTINGS.read_options(path)

    def render(self, choices=None, key=""):
        output = self.root / "settings.nix"
        args = argparse.Namespace(output=output, user="alice", uid=1007, home="/home/alice",
                                  hostname="work-pc", state_version="25.05", ssh="false", ssh_key=key)
        SETTINGS.render(args, SETTINGS.read_options(None) if choices is None else choices)
        return output.read_text(encoding="utf-8")

    def test_original_state_and_user_are_preserved(self):
        text = self.render()
        self.assertIn('username = "alice"; uid = 1007;', text)
        self.assertIn('stateVersion = "25.05";', text)
        self.assertIn('enable = false; port = 5555; authorizedKeys = [', text)

    def test_selected_components_and_ports_reach_the_local_module(self):
        choices = self.options({"development": False, "virtualisation": False, "vpn": False,
                                "rdp": False, "rdpPort": 3391, "sshPort": 2222,
                                "timezone": "Etc/UTC", "stateVersion": "26.05"})
        text = self.render(choices)
        for name in ("development", "virtualisation", "vpn"):
            self.assertIn(f"{name}.enable = false;", text)
        self.assertIn('services.bspwmRdp = { enable = false; port = 3391; };', text)
        self.assertIn('timeZone = "Etc/UTC";', text)
        self.assertIn('stateVersion = "26.05";', text)
        self.assertIn('port = 2222;', text)

    def test_port_boundaries_and_types(self):
        for value in (0, 65536, True, "3389", -1):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.options({"rdpPort": value})
        for value in (1, 65535):
            self.assertEqual(self.options({"rdpPort": value})["rdpPort"], value)

    def test_boolean_fields_cannot_contain_nix_expressions(self):
        for value in ("true", 1, None, "${builtins.abort \"bad\"}"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.options({"vpn": value})

    def test_unknown_options_and_wrong_container_are_rejected(self):
        for value in ({"arbitraryCode": "anything"}, [], None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.options(value)

    def test_timezone_and_state_version_are_validated(self):
        for data in ({"timezone": '${builtins.abort "bad"}'}, {"stateVersion": "26.05;"}, {"stateVersion": 26.05}):
            with self.subTest(value=data), self.assertRaises(ValueError):
                self.options(data)

    def test_public_key_comments_cannot_interpolate_nix_code(self):
        key = self.root / "test.pub"
        key.write_text('ssh-ed25519 AAAA comment ${builtins.abort "bad"}\n', encoding="utf-8")
        text = self.render(key=str(key))
        self.assertIn(r'\${builtins.abort', text)
        self.assertIn('ssh-ed25519 AAAA', text)

    def test_private_key_is_rejected(self):
        key = self.root / "private.key"
        key.write_text('-----BEGIN OPENSSH PRIVATE KEY-----\n', encoding="utf-8")
        with self.assertRaises(ValueError):
            self.render(key=str(key))


if __name__ == "__main__":
    unittest.main()
