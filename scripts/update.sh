#!/usr/bin/env bash
set -euo pipefail
# Updating repository code is separate from applying your local configuration.
target=${1:-/etc/nixos}
[ "$(id -u)" -eq 0 ] || { printf 'Run with sudo.\n' >&2; exit 1; }
[ -d "$target/.git" ] || { printf 'No Git checkout in %s\n' "$target" >&2; exit 1; }
[ -z "$(git -C "$target" status --porcelain)" ] || {
  printf 'Save or commit edits to repository files before pulling.\nLocal configuration.nix can be edited and rebuilt without pulling.\n' >&2
  exit 1
}
git -C "$target" pull --ff-only
nixos-rebuild build -I "nixos-config=$target/configuration.nix"
printf 'Build succeeded. Apply with: sudo nixos-rebuild switch -I nixos-config=%s/configuration.nix\n' "$target"
