"""Run the built RDP session on an isolated X server with no user D-Bus.

Set NIXOS_BSPWM_RDP_SESSION to the built session script from the xrdp config.
This verifies that an unavailable desktop agent cannot terminate the WM.
"""
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

XVFB = shutil.which('Xvfb') or next((str(p) for p in Path('/nix/store').glob('*xorg-server*/bin/Xvfb')), None)
SESSION = os.environ.get('NIXOS_BSPWM_RDP_SESSION')


@unittest.skipUnless(SESSION and XVFB and shutil.which('bspc'), 'Built RDP session and Xvfb required')
class RdpStartupTests(unittest.TestCase):
    def test_unavailable_user_services_do_not_close_the_desktop(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            env = dict(os.environ)
            for key, directory in [('HOME', 'home'), ('XDG_CONFIG_HOME', 'config'),
                                   ('XDG_DATA_HOME', 'data'), ('XDG_CACHE_HOME', 'cache'),
                                   ('XDG_STATE_HOME', 'state'), ('XDG_RUNTIME_DIR', 'run')]:
                path = root / directory
                path.mkdir(mode=0o700)
                env[key] = str(path)
            env['XAUTHORITY'] = '/dev/null'
            env['BSPWM_SOCKET'] = str(root / 'bspwm.sock')
            server = subprocess.Popen([XVFB, '-displayfd', '1', '-screen', '0', '1024x768x24',
                                       '-nolisten', 'tcp', '-noreset', '-ac'],
                                      stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            desktop = None
            try:
                self.assertTrue(select.select([server.stdout], [], [], 10)[0], 'Xvfb did not start')
                env['DISPLAY'] = ':' + server.stdout.readline().strip()
                with (root / 'session.log').open('w') as log:
                    desktop = subprocess.Popen([SESSION], env=env, stdout=log, stderr=log,
                                               start_new_session=True)
                    deadline = time.monotonic() + 12
                    while not Path(env['BSPWM_SOCKET']).exists():
                        self.assertIsNone(desktop.poll(), (root / 'session.log').read_text())
                        self.assertLess(time.monotonic(), deadline, (root / 'session.log').read_text())
                        time.sleep(.1)
                    result = subprocess.run(['bspc', '-s', env['BSPWM_SOCKET'], 'query', '-M', '--names'],
                                            env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(result.stdout.strip(), 'A working BSPWM monitor is required')
                    self.assertIsNone(desktop.poll())
                    self.assertIn('continuing with BSPWM', (root / 'session.log').read_text())
            finally:
                if desktop is not None:
                    try:
                        os.killpg(desktop.pid, signal.SIGTERM)
                        desktop.wait(timeout=5)
                    except ProcessLookupError:
                        pass
                    except subprocess.TimeoutExpired:
                        os.killpg(desktop.pid, signal.SIGKILL)
                        desktop.wait()
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
                server.stdout.close()


if __name__ == '__main__':
    unittest.main()
