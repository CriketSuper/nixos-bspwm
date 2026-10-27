"""Exercise the real installer in a temporary directory, never in /etc/nixos."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NIXOS_UEFI = Path('/etc/NIXOS').exists() and Path('/sys/firmware/efi').is_dir()


@unittest.skipUnless(NIXOS_UEFI and shutil.which('nix-instantiate'), 'NixOS/UEFI tools required')
class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.source = self.work / 'source'
        self.source.mkdir()
        tracked = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '--cached', '--others', '--exclude-standard', '-z'])
        for name in tracked.decode().split('\0'):
            if not name or not (ROOT / name).is_file():
                continue
            dest = self.source / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, dest)
        self.run_git('init', '-q')
        self.run_git('add', '.')
        self.run_git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Fixture')
        # Ignored local content must not be included even from the source checkout.
        (self.source / 'private.nix').write_text('throw "SOURCE_PRIVATE_CANARY"')
        (self.source / 'vendor').mkdir()
        (self.source / 'vendor/token.key').write_text('SOURCE_KEY_CANARY')
        self.target = self.work / 'etc/nixos'
        (self.target / 'local').mkdir(parents=True)
        (self.target / 'local/settings.nix').write_text('{...}: { bspwmBuild.stateVersion = "25.05"; }')
        self.hardware = '{ ... }: { fileSystems."/" = { device = "/dev/disk/by-uuid/TARGET-PC"; fsType = "ext4"; }; }\n'
        (self.target / 'local/hardware-configuration.nix').write_text(self.hardware)
        (self.target / 'local/private.nix').write_text('throw "TARGET_PRIVATE_CANARY"')
        (self.target / 'flake.nix').write_text('throw "OLD_FLAKE_MUST_NOT_RUN"')
        (self.target / 'configuration.nix').write_text('{ ... }: { system.stateVersion = "26.05"; }')
        self.bin = self.work / 'bin'
        self.bin.mkdir()
        self.shim('id', 'if [ "$#" = 1 ]; then echo 0; else echo 1007; fi')
        self.shim('getent', 'echo "alice:x:1007:100::/home/alice:/bin/sh"')
        self.shim('nixos-generate-config', 'echo "Hardware generator should not run" >&2; exit 99')
        self.shim('nixos-rebuild', 'echo "$*" >> "$TEST_REBUILD_LOG"; exit "${TEST_REBUILD_STATUS:-0}"')
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', TEST_REBUILD_LOG=str(self.work / 'rebuild.log'))

    def run_git(self, *args):
        subprocess.run(['git', '-C', str(self.source), *args], check=True, capture_output=True)

    def shim(self, name, body):
        file = self.bin / name
        file.write_text('#!/usr/bin/env bash\n' + body + '\n')
        file.chmod(0o755)

    def install(self, *args):
        return subprocess.run(['bash', str(self.source / 'scripts/install.sh'), '--target', str(self.target),
                               '--backup-root', str(self.work / 'backups'), '--profile', 'universal',
                               '--user', 'alice', '--hostname', 'other-pc', *args],
                              env=self.env, text=True, capture_output=True)

    def test_migrate_without_importing_private_files_or_flakes(self):
        result = self.install('--replace', '--mode', 'prepare', '--ssh-mode', 'password')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        config = (self.target / 'configuration.nix').read_text()
        self.assertIn('system.stateVersion = "25.05";', config)
        self.assertIn('PasswordAuthentication = true;', config)
        self.assertIn('PubkeyAuthentication = false;', config)
        self.assertNotIn('authorizedKeys', config)
        self.assertNotIn('private', config)
        self.assertEqual((self.target / 'hardware-configuration.nix').read_text(), self.hardware)
        for name in ('local', 'private.nix', 'vendor', 'flake.nix', 'flake.lock', 'bspwm-repo'):
            self.assertFalse((self.target / name).exists(), name)
        backup = next((self.work / 'backups').iterdir())
        self.assertEqual(backup.stat().st_mode & 0o777, 0o700)
        self.assertTrue((backup / 'config-before/local/private.nix').exists())
        status = subprocess.check_output(['git', '-C', str(self.target), 'status', '--porcelain'], text=True)
        self.assertEqual(status, '')
        self.assertFalse((self.work / 'rebuild.log').exists())

    def test_requires_explicit_replace_before_moving_old_files(self):
        result = self.install('--mode', 'prepare')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.target / 'flake.nix').exists())
        self.assertFalse((self.work / 'backups').exists())

    def test_failed_build_never_switches(self):
        self.env['TEST_REBUILD_STATUS'] = '23'
        result = self.install('--replace', '--mode', 'switch')
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        calls = (self.work / 'rebuild.log').read_text()
        self.assertTrue(calls.startswith('build -I nixos-config='), calls)
        self.assertNotIn('switch', calls)
        self.assertNotIn('--flake', calls)
        self.assertTrue((self.target / 'configuration.nix').exists())

    def test_first_activation_hint_resolves_config_in_an_old_search_path(self):
        result = self.install('--replace', '--mode', 'build')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        mapping = f'nixos-config={self.target}/configuration.nix'
        self.assertIn(f'sudo nixos-rebuild switch -I {mapping}', result.stdout)
        # Reproduce an old environment with only nixpkgs in NIX_PATH.
        env = dict(self.env, NIX_PATH=f'nixpkgs={self.work}')
        env.pop('NIXOS_CONFIG', None)
        missing = subprocess.run(['nix-instantiate', '--find-file', 'nixos-config'],
                                 env=env, text=True, capture_output=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("file 'nixos-config' was not found", missing.stderr)
        resolved = subprocess.run(['nix-instantiate', '-I', mapping, '--find-file', 'nixos-config'],
                                  env=env, text=True, capture_output=True)
        self.assertEqual(resolved.returncode, 0, resolved.stderr)
        self.assertEqual(resolved.stdout.strip(), str(self.target / 'configuration.nix'))
