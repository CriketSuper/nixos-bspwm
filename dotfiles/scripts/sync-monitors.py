#!/usr/bin/env python3
"""Refresh existing desktops after RandR changes, keeping windows and desktop IDs."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import time


def run(*args, check=True):
    result = subprocess.run(args, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(f'{args[0]}: {result.stderr.strip()}')
    return result.stdout.strip()


def state():
    return json.loads(run('bspc', 'wm', '-d'))


def sync():
    if not run('bspc', 'query', '-M', '--names', check=False):
        return
    focused_node = run('bspc', 'query', '-N', '-n', 'focused', check=False)
    focused_desktop = run('bspc', 'query', '-D', '-d', 'focused', check=False)
    for setting in ('remove_disabled_monitors', 'remove_unplugged_monitors',
                    'merge_overlapping_monitors'):
        run('bspc', 'config', setting, 'true')
    active = []
    for line in run('xrandr', '--query').splitlines():
        match = re.match(r'(\S+) connected (primary )?(\d+)x(\d+)\+(-?\d+)\+(-?\d+)', line)
        if match:
            name, primary, width, height, x, y = match.groups()
            active.append((not bool(primary), int(x), int(y), name))
    if not active:
        return
    active.sort()
    names = [entry[3] for entry in active]
    for _ in range(20):
        wm = state()
        available = {monitor['name'] for monitor in wm['monitors']}
        if set(names) <= available:
            break
        time.sleep(0.1)
    # Mirror mode can merge overlapping RandR outputs into one BSPWM monitor.
    monitors = [name for name in names if name in available]
    if not monitors:
        return
    owners = {d['name']: m['name'] for m in wm['monitors'] for d in m['desktops']}
    sizes = {m['name']: len(m['desktops']) for m in wm['monitors']}
    existing = {desktop['name'] for monitor in wm['monitors']
                for desktop in monitor['desktops']}
    for number in range(1, 10):
        if str(number) not in existing:
            run('bspc', 'monitor', monitors[0], '-a', str(number))
            owners[str(number)] = monitors[0]
            sizes[monitors[0]] += 1
    # Primary gets 1-5 with two screens; three screens get 1-3, 4-6, 7-9.
    count = min(len(monitors), 9)
    offset = 1
    for index, monitor in enumerate(monitors[:count]):
        size = 9 // count + (index < 9 % count)
        for number in range(offset, offset + size):
            source = owners[str(number)]
            if source != monitor:
                # BSPWM requires at least one desktop on each monitor.
                if sizes[source] == 1:
                    run('bspc', 'monitor', source, '-a', 'Desktop')
                    sizes[source] += 1
                run('bspc', 'desktop', str(number), '-m', monitor)
                sizes[source] -= 1
                sizes[monitor] += 1
        offset += size
    # Only delete the empty default placeholders, never user desktops/windows.
    for monitor in state()['monitors']:
        desktops = monitor['desktops']
        for desktop in desktops:
            if (len(desktops) > 1 and desktop['root'] is None
                    and re.fullmatch(r'Desktop\d*', desktop['name'])):
                run('bspc', 'desktop', str(desktop['id']), '-r', check=False)
        remaining = [d['name'] for m in state()['monitors']
                     if m['name'] == monitor['name'] for d in m['desktops']]
        numeric = sorted((n for n in remaining if n in map(str, range(1, 10))), key=int)
        others = [n for n in remaining if n not in numeric]
        if remaining:
            run('bspc', 'monitor', monitor['name'], '-o', *numeric, *others)
    if focused_node:
        run('bspc', 'node', focused_node, '-f', check=False)
    elif focused_desktop:
        run('bspc', 'desktop', focused_desktop, '-f', check=False)
    # Respect a bar hidden with Super+P.
    if subprocess.run(['pgrep', '-x', 'polybar'], capture_output=True).returncode == 0:
        subprocess.run([str(Path.home()/'.config/polybar/launch.sh')], check=True)
    wallpaper_cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home()/'.cache'))) / 'bspwm-wallpaper'
    if wallpaper_cache.exists():
        wallpaper = wallpaper_cache.read_text().strip()
        if Path(wallpaper).is_file():
            subprocess.run(['feh', '--no-fehbg', '--bg-fill', wallpaper], check=True)


if __name__ == '__main__':
    lock_path = Path(os.environ.get('XDG_RUNTIME_DIR', str(Path.home()/'.cache'))) / 'monitor-sync.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        sync()
