#!/usr/bin/env python3
"""Track only public runtime files; machine configuration and secrets are excluded."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

RUNTIME = ('docs', 'dotfiles', 'home.nix', 'modules', 'packages', 'profiles',
           'services', 'sources.nix', 'users.nix')


def hashes(target):
    result = {}
    for name in RUNTIME:
        path = target / name
        paths = path.rglob('*') if path.is_dir() else [path]
        for file in paths:
            if file.is_file():
                result[str(file.relative_to(target))] = hashlib.sha256(file.read_bytes()).hexdigest()
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('write', 'check'))
    p.add_argument('--target', type=Path, required=True)
    p.add_argument('--state-root', type=Path, required=True)
    p.add_argument('--nixpkgs', default='')
    p.add_argument('--user', default='')
    args = p.parse_args()
    filename = args.state_root / 'deployment.json'
    if args.action == 'write':
        revision = subprocess.check_output(['git', '-C', str(args.state_root / 'source'), 'rev-parse', 'HEAD'], text=True).strip()
        data = dict(revision=revision, nixpkgs=args.nixpkgs, target=str(args.target), username=args.user, files=hashes(args.target))
        filename.write_text(json.dumps(data, indent=2) + '\n')
    else:
        data = json.loads(filename.read_text())
        current = hashes(args.target)
        changed = sorted(name for name in set(data['files']) | set(current)
                         if data['files'].get(name) != current.get(name))
        if changed:
            print('Save/merge local edits before updating shared runtime files:', file=sys.stderr)
            print('\n'.join(changed), file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
