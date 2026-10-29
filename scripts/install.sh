#!/usr/bin/env bash
# Install on the TARGET PC. No partitioning, passwords or private files are copied.
set -euo pipefail
umask 022
export LC_ALL=C LANGUAGE=C
profile=universal
profile_explicit=false
username=${SUDO_USER:-}
host_name=''
mode=build
target=/etc/nixos
backup_root=/var/backups/nixos-bspwm
state_root=/var/lib/nixos-bspwm
ssh_key=''
ssh_mode=off
replace=false
settings_json=''
state_version=''
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$script_dir/.." && pwd)
usage() {
  cat <<'HELP'
Usage: sudo bash scripts/install.sh [options]
  --profile NAME    universal (default) or huawei-matebook-d16
  --user NAME       Existing normal user on THIS PC; password stays in place
  --hostname NAME   Hostname (default: this PC's hostname)
  --mode MODE       prepare, build (default), or switch
  --target DIR      Default: /etc/nixos
  --backup-root DIR Default: /var/backups/nixos-bspwm (local, root-only)
  --state-root DIR  Installer/Git state outside /etc/nixos; default: /var/lib/nixos-bspwm
  --state-version YY.MM  Original installation version, if not detected
  --ssh-mode MODE   off (default), password, or key
  --ssh-key FILE    Explicitly add a public key (requires --ssh-mode key)
  --settings-json FILE  Wizard choices
  --replace        Migrate an existing desktop deployment after backing it up
  --help           Show help
Run from a clean, committed Git checkout on installed NixOS 26.05, x86_64/UEFI.
Only tracked repository files and THIS PC's hardware config are deployed.
Migration from flakes does not import old private modules or keys.
An existing native configuration keeps its own local files on THIS PC.
Old files remain in a local root-only backup for rollback.
HELP
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need_value() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "Missing value for $1"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) need_value "$@"; profile=$2; profile_explicit=true; shift 2 ;;
    --user) need_value "$@"; username=$2; shift 2 ;;
    --hostname) need_value "$@"; host_name=$2; shift 2 ;;
    --mode) need_value "$@"; mode=$2; shift 2 ;;
    --target) need_value "$@"; target=$2; shift 2 ;;
    --backup-root) need_value "$@"; backup_root=$2; shift 2 ;;
    --state-root) need_value "$@"; state_root=$2; shift 2 ;;
    --state-version) need_value "$@"; state_version=$2; shift 2 ;;
    --ssh-mode) need_value "$@"; ssh_mode=$2; shift 2 ;;
    --ssh-key) need_value "$@"; ssh_key=$2; shift 2 ;;
    --settings-json) need_value "$@"; settings_json=$2; shift 2 ;;
    --replace) replace=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
[ "$(id -u)" -eq 0 ] || die 'Run with sudo.'
[ -e /etc/NIXOS ] || die 'An installed NixOS is required.'
[ "$(uname -m)" = x86_64 ] || die 'Only x86_64 Intel/AMD is supported.'
[ -d /sys/firmware/efi ] || die 'For BIOS use the manual installation instructions.'
case "$mode" in prepare|build|switch) ;; *) die 'Invalid mode.' ;; esac
case "$profile" in universal|huawei-matebook-d16) ;; *) die 'Unknown profile.' ;; esac
case "$ssh_mode" in off|password|key) ;; *) die 'Invalid SSH mode.' ;; esac
for path in "$target" "$backup_root" "$state_root"; do
  [[ "$path" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 'Use absolute paths without spaces.'
  [ "$(realpath -m -- "$path")" != / ] || die 'Path cannot be /.'
done
[ ! -L "$target" ] || die 'The deployment must not be a symlink.'
target=$(realpath -m -- "$target")
backup_root=$(realpath -m -- "$backup_root")
state_root=$(realpath -m -- "$state_root")
case "$backup_root/" in "$target/"*) die 'Backups must be outside the deployment.' ;; esac
case "$state_root/" in "$target/"*) die 'Installer state must be outside /etc/nixos.' ;; esac
native=false
if [ ! -e "$target/flake.nix" ] && [ -f "$target/configuration.nix" ] && grep -Eq '\./modules([/[:space:]]|$)' "$target/configuration.nix"; then
  native=true
  if ! "$profile_explicit"; then
    detected=$(sed -nE 's|^[[:space:]]*\./profiles/([a-z0-9-]+)\.nix.*|\1|p' "$target/configuration.nix" | head -n 1)
    profile=${detected:-universal}
  fi
fi
case "$profile" in universal|huawei-matebook-d16) ;; *) die 'Unknown installed profile; specify --profile.' ;; esac
if [ -z "$username" ] || [ "$username" = root ]; then username=$(getent passwd 1000 | cut -d : -f 1); fi
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || die 'Specify a valid --user.'
getent passwd "$username" >/dev/null || die "Create a normal user first: $username"
uid=$(id -u "$username")
[ "$uid" -ge 1000 ] || die 'Select a normal user.'
home_dir=$(getent passwd "$username" | cut -d : -f 6)
[[ "$home_dir" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 'Unsupported home path.'
host_name=${host_name:-$(hostname)}
[[ "$host_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || die 'Invalid hostname.'
if [ "$profile" = huawei-matebook-d16 ]; then
  grep -q AuthenticAMD /proc/cpuinfo || die 'This Huawei profile requires AMD.'
fi
for command in git nix-instantiate nixos-generate-config python3; do
  command -v "$command" >/dev/null || die "Missing command: $command"
done
[ -f "$source_dir/sources.nix" ] || die 'Run from a complete checkout.'
[ -z "$(git -c safe.directory="$source_dir" -C "$source_dir" status --porcelain --untracked-files=normal)" ] || die 'Commit/save source changes before deploying. Local configuration.nix and hardware files are ignored by Git.'
if [ -e "$target/flake.nix" ] || [ -d "$target/modules" ] || [ -e "$target/bspwm-repo" ]; then
  "$replace" || die 'An earlier desktop deployment exists. Review it, then use --replace.'
fi
nixpkgs_path=$(nix-instantiate --find-file nixpkgs)
[ -d "$nixpkgs_path/nixos" ] || die 'The nixpkgs source must contain the NixOS modules.'
settings_options=()
if [ -n "$settings_json" ]; then settings_options=(--options "$settings_json"); fi
python3 "$script_dir/render-settings.py" --validate-only "${settings_options[@]}"
if [ -z "$state_version" ]; then
  state_version=$(python3 "$script_dir/render-settings.py" --detect-state "$target") || die 'Specify the ORIGINAL --state-version YY.MM.'
fi
[[ "$state_version" =~ ^[0-9]{2}\.[0-9]{2}$ ]] || die 'Invalid stateVersion.'
if [ "$mode" = switch ] && [ "$ssh_mode" = key ] && [ -z "$ssh_key" ]; then
  die 'Key authentication needs --ssh-key before automatic switch. Use --mode build to edit authorizedKeys first.'
fi
if [ -n "$ssh_key" ]; then
  [ "$ssh_mode" = key ] || die '--ssh-key requires --ssh-mode key.'
  if [ ! -f "$ssh_key" ] || grep -q 'PRIVATE KEY' "$ssh_key"; then die 'Only a public SSH key is accepted.'; fi
  ssh-keygen -lf "$ssh_key" >/dev/null || die 'Invalid public SSH key.'
fi
mkdir -p -- "$(dirname -- "$target")"
stage=$(mktemp -d "${target}.stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
# A clean clone excludes ignored private files, runtime configs and credentials.
git -c safe.directory="$source_dir" clone --quiet --no-local -- "$source_dir" "$stage/source"
git -C "$stage/source" remote set-url origin https://github.com/CriketSuper/nixos-bspwm.git
mkdir "$stage/repo"
# Deploy runtime modules/assets only. Keep Git, tests and installer code elsewhere.
for component in docs dotfiles home.nix modules packages profiles services sources.nix users.nix; do
  cp -a -- "$stage/source/$component" "$stage/repo/$component"
done
install -m 644 "$stage/source/LICENSE" "$stage/repo/docs/LICENSE"
hardware="$target/hardware-configuration.nix"
if [ -f "$target/flake.nix" ] && [ -f "$target/local/hardware-configuration.nix" ]; then hardware="$target/local/hardware-configuration.nix"; fi
if [ -f "$hardware" ]; then
  cp -L -- "$hardware" "$stage/repo/hardware-configuration.nix"
else
  nixos-generate-config --show-hardware-config > "$stage/repo/hardware-configuration.nix"
fi
if "$native"; then
  # Retain this PC's SSH access and all native local settings when upgrading.
  cp -L -- "$target/configuration.nix" "$stage/repo/configuration.nix"
  # Keep existing machine-local modules on THIS PC; never source them from the
  # laptop or the Git checkout. Their values are excluded from deployment state.
  for local_file in "$target"/*.nix; do
    [ -f "$local_file" ] || continue
    name=$(basename "$local_file")
    [ -e "$stage/repo/$name" ] || cp -a -- "$local_file" "$stage/repo/$name"
  done
  for local_dir in local keys private vendor; do
    [ ! -d "$target/$local_dir" ] || cp -a -- "$target/$local_dir" "$stage/repo/$local_dir"
  done
  if "$profile_explicit"; then
    sed -i -E "s@\./profiles/(universal|huawei-matebook-d16)\.nix@./profiles/$profile.nix@" "$stage/repo/configuration.nix"
  fi
else
  python3 "$script_dir/render-settings.py" \
    --output "$stage/repo/configuration.nix" --profile "$profile" \
    --user "$username" --uid "$uid" --home "$home_dir" --hostname "$host_name" \
    --state-version "$state_version" --ssh-mode "$ssh_mode" --ssh-key "$ssh_key" "${settings_options[@]}"
fi
chmod 644 "$stage/repo/configuration.nix" "$stage/repo/hardware-configuration.nix"
# Check syntax before moving the old directory. No old Nix expressions are run.
nix-instantiate --parse "$stage/repo/configuration.nix" >/dev/null
nix-instantiate --parse "$stage/repo/hardware-configuration.nix" >/dev/null
backup="$backup_root/$(date +%Y%m%d-%H%M%S)-$$"
install -d -m 700 "$backup_root" "$backup"
readlink -f /run/current-system > "$backup/system-path.txt"
if [ "$target" = /etc/nixos ]; then
  install -d /nix/var/nix/gcroots
  ln -s "$(readlink -f /run/current-system)" "/nix/var/nix/gcroots/bspwm-before-$(basename "$backup")"
fi
if [ -d "$target" ]; then mv -- "$target" "$backup/config-before"; fi
if ! mv -- "$stage/repo" "$target"; then
  [ ! -d "$backup/config-before" ] || mv -- "$backup/config-before" "$target"
  die 'Deployment failed; original directory restored.'
fi
install -d -m 755 "$state_root"
[ ! -e "$state_root/source" ] || mv -- "$state_root/source" "$backup/previous-source"
mv -- "$stage/source" "$state_root/source"
python3 "$state_root/source/scripts/deployment-state.py" write --target "$target" \
  --state-root "$state_root" --nixpkgs "$nixpkgs_path" --user "$username"
printf 'Profile: %s\nLocal backup: %s\nConfiguration: %s/configuration.nix\n'  "$profile" "$backup" "$target"
printf 'Nixpkgs frozen at: %s\nInstaller source: %s/source\n' "$nixpkgs_path" "$state_root"
if "$native"; then printf 'Existing configuration.nix was preserved.\n'; else printf 'Private files were not imported. The existing account password stays in place.\n'; fi
case "$mode" in
  prepare) printf 'Prepared. Build: sudo nixos-rebuild build -I nixos-config=%s/configuration.nix -I nixpkgs=%s\n' "$target" "$nixpkgs_path" ;;
  build|switch)
    (cd "$stage" && nixos-rebuild build -I "nixos-config=$target/configuration.nix" -I "nixpkgs=$nixpkgs_path")
    if [ "$mode" = switch ]; then
      nixos-rebuild switch -I "nixos-config=$target/configuration.nix" -I "nixpkgs=$nixpkgs_path"
      printf 'Activated. Reboot when convenient.\n'
    else printf 'Build succeeded. Apply with: sudo bash %s/source/scripts/activate.sh %s\n' "$state_root" "$state_root"
    fi ;;
esac
