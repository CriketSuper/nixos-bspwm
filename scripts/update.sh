#!/usr/bin/env bash
set -euo pipefail
# Fast-forward only. The pinned nixpkgs/HM versions stay unchanged.
target=${1:-/etc/nixos}
[ "$(id -u)" -eq 0 ] || { printf 'Run with sudo.\n' >&2; exit 1; }
[ -d "$target/bspwm-repo/.git" ] || { printf 'No Git checkout in %s/bspwm-repo\n' "$target" >&2; exit 1; }
[ -z "$(git -C "$target/bspwm-repo" status --porcelain)" ] || { printf 'Commit or save local repository changes first.\n' >&2; exit 1; }
git -C "$target/bspwm-repo" pull --ff-only
nix --extra-experimental-features 'nix-command flakes' flake update --flake "path:$target" bspwm
NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild build --flake "path:$target#current"
printf 'Build succeeded. Apply with: sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake path:%s#current\n' "$target"
