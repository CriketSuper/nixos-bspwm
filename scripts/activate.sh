#!/usr/bin/env bash
# First activation uses exactly the source chosen by the installer.
set -euo pipefail
state_root=${1:-/var/lib/nixos-bspwm}
[ "$(id -u)" -eq 0 ] || { printf 'Run with sudo.\n' >&2; exit 1; }
mapfile -t settings < <(python3 - "$state_root/deployment.json" <<'PY'
import json,sys
state=json.load(open(sys.argv[1]))
print(state['nixpkgs'])
print(state.get('target','/etc/nixos'))
PY
)
[ "${#settings[@]}" -eq 2 ] || { printf 'Invalid deployment metadata.\n' >&2; exit 1; }
[ -d "${settings[0]}/nixos" ] && [ -f "${settings[1]}/configuration.nix" ] || { printf 'Source or configuration is missing.\n' >&2; exit 1; }
exec nixos-rebuild switch -I "nixos-config=${settings[1]}/configuration.nix" -I "nixpkgs=${settings[0]}"
