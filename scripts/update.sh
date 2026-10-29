#!/usr/bin/env bash
# Update shared desktop code, keeping local configuration and package versions.
set -euo pipefail
target=${1:-/etc/nixos}
state_root=${2:-/var/lib/nixos-bspwm}
[ "$(id -u)" -eq 0 ] || { printf 'Run with sudo.\n' >&2; exit 1; }
source_dir="$state_root/source"
[ -d "$source_dir/.git" ] || { printf 'No installer source in %s. Run the current installer once with --replace.\n' "$source_dir" >&2; exit 1; }
[ -z "$(git -C "$source_dir" status --porcelain)" ] || { printf 'Save changes in the installer source first.\n' >&2; exit 1; }
python3 "$source_dir/scripts/deployment-state.py" check --target "$target" --state-root "$state_root"
username=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["username"])' "$state_root/deployment.json")
git -C "$source_dir" pull --ff-only
exec bash "$source_dir/scripts/install.sh" --replace --user "$username" \
  --target "$target" --state-root "$state_root" --mode build
