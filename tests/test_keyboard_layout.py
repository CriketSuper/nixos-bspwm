"""Real X11 regression tests: Alt+Shift and recovery after an RDP-style reset."""
import ctypes
import ctypes.util
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
XVFB = shutil.which('Xvfb') or next((str(p) for p in Path('/nix/store').glob('*xorg-server*/bin/Xvfb')), None)


def library(name, pattern):
    candidates = []
    found = ctypes.util.find_library(name)
    if found:
        candidates.append(found)
    candidates.extend(str(p) for p in Path('/nix/store').glob(pattern))
    for candidate in candidates:
        try:
            return ctypes.CDLL(candidate)
        except OSError:
            pass  # A Nix store can contain both 32-bit and 64-bit libraries.
    raise unittest.SkipTest(f'No usable {name} library')


@unittest.skipUnless(XVFB and shutil.which('setxkbmap') and shutil.which('flock'), 'Xvfb/XKB tools required')
class KeyboardLayoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.server = subprocess.Popen([XVFB, '-displayfd', '1', '-screen', '0', '1024x768x24',
                                        '-nolisten', 'tcp', '-noreset', '-ac'],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.addCleanup(self.stop, self.server)
        if not select.select([self.server.stdout], [], [], 10)[0]:
            self.fail('Xvfb did not start')
        self.display_name = ':' + self.server.stdout.readline().strip()
        self.env = dict(os.environ, DISPLAY=self.display_name, XDG_RUNTIME_DIR=self.temp.name,
                        XAUTHORITY='/dev/null')
        self.x = library('X11', '*libx11-*/lib/libX11.so.6')
        self.xt = library('Xtst', '*libxtst-*/lib/libXtst.so.6')
        self.x.XOpenDisplay.argtypes = [ctypes.c_char_p]
        self.x.XOpenDisplay.restype = ctypes.c_void_p
        self.x.XCloseDisplay.argtypes = [ctypes.c_void_p]
        self.x.XkbGetState.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p]
        self.x.XkbLockGroup.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint]
        self.x.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.x.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        self.x.XKeysymToKeycode.restype = ctypes.c_uint
        self.xt.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        self.display = self.x.XOpenDisplay(self.display_name.encode())
        self.assertTrue(self.display)
        self.addCleanup(self.x.XCloseDisplay, self.display)

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if process.stdout:
            process.stdout.close()
        if process.stderr:
            process.stderr.close()

    def run_xkb(self, *args):
        return subprocess.run(['setxkbmap', *args], env=self.env, check=True,
                              text=True, capture_output=True).stdout

    def group(self):
        state = ctypes.create_string_buffer(64)
        self.assertEqual(self.x.XkbGetState(self.display, 0x100, state), 0)
        return state.raw[0]

    def select_group(self, group):
        self.x.XkbLockGroup(self.display, 0x100, group)
        self.x.XSync(self.display, 0)

    def alt_shift(self):
        # xdotool restores the original XKB group afterward; inject the real
        # modifier events instead to verify the server's group-switch action.
        alt = self.x.XKeysymToKeycode(self.display, 0xFFE9)
        shift = self.x.XKeysymToKeycode(self.display, 0xFFE1)
        for key, pressed in ((alt, 1), (shift, 1), (shift, 0), (alt, 0)):
            self.xt.XTestFakeKeyEvent(self.display, key, pressed, 0)
            self.x.XSync(self.display, 0)

    def test_english_russian_alt_shift_switches_both_ways(self):
        subprocess.run(['sh', str(ROOT / 'dotfiles/scripts/keyboard-layout.sh'), '--once'],
                       env=self.env, check=True)
        self.select_group(0)
        self.alt_shift()
        self.assertEqual(self.group(), 1)
        self.alt_shift()
        self.assertEqual(self.group(), 0)

    def test_reconnect_reset_is_repaired_without_interrupting_russian_typing(self):
        guard = subprocess.Popen(['sh', str(ROOT / 'dotfiles/scripts/keyboard-layout.sh'), '--watch'],
                                 env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop, guard)
        deadline = time.monotonic() + 6
        while 'us,ru' not in self.run_xkb('-query'):
            self.assertLess(time.monotonic(), deadline)
            time.sleep(.1)
        self.select_group(1)
        time.sleep(2.3)
        self.assertEqual(self.group(), 1, 'Guard must not repeatedly force English')
        self.run_xkb('-layout', 'us', '-option', '')
        deadline = time.monotonic() + 6
        while 'us,ru' not in self.run_xkb('-query'):
            self.assertLess(time.monotonic(), deadline)
            time.sleep(.1)
        self.select_group(0)
        self.alt_shift()
        self.assertEqual(self.group(), 1)
        self.assertIsNone(guard.poll())
