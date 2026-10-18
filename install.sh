#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  cat <<'HELP'
NixOS BSPWM installer
  ./install.sh                 Interactive setup wizard
  ./install.sh --wizard ...    Wizard options: --target DIR
  ./install.sh --profile ...   Command-line installer (see scripts/install.sh --help)
Requires an existing x86_64 NixOS installation with UEFI and a normal user.
HELP
  exit 0
fi
if [ "$#" -gt 0 ] && [ "$1" != --wizard ]; then
  exec bash "$repo_dir/scripts/install.sh" "$@"
fi
[ "${1:-}" != --wizard ] || shift
exec bash "$repo_dir/scripts/install-wizard.sh" "$@"
