#!/usr/bin/env bash
# Install this desktop on an existing NixOS system; never partition or format disks.
set -euo pipefail
umask 022
export LC_ALL=C LANGUAGE=C
repo_url=''
ref=main
profile=''
username=${SUDO_USER:-}
hostname=''
mode=build
target=/etc/nixos
ssh_key=''
ssh_enable=false
replace=false
settings_json=''
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

usage() {
  cat <<'HELP'
Usage: sudo bash scripts/install.sh [options]
  --repo URL        Clone a Git repository (otherwise use this local checkout)
  --ref REF         Branch or tag to clone, default: main
  --profile NAME    universal or huawei-matebook-d16
  --user NAME       Existing normal user; its password is preserved
  --hostname NAME   Host name, default: current host name
  --mode MODE       prepare, build (default), or switch
  --target DIR      Deployment directory, default: /etc/nixos
  --ssh-key FILE    Add this public SSH key and enable SSH on port 5555
  --enable-ssh      Enable SSH with key authentication (no keys added)
  --settings-json FILE  Validated wizard settings (new deployment only)
  --replace        Replace an earlier deployment; keep its local settings
  --help           Show this help
Requires an installed x86_64 NixOS system with UEFI and a normal user.
No disk formatting. A private configuration backup is saved before any changes.
HELP
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need_value() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "Missing value for $1"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; repo_url=$2; shift 2 ;;
    --ref) need_value "$@"; ref=$2; shift 2 ;;
    --profile) need_value "$@"; profile=$2; shift 2 ;;
    --user) need_value "$@"; username=$2; shift 2 ;;
    --hostname) need_value "$@"; hostname=$2; shift 2 ;;
    --mode) need_value "$@"; mode=$2; shift 2 ;;
    --target) need_value "$@"; target=$2; shift 2 ;;
    --ssh-key) need_value "$@"; ssh_key=$2; ssh_enable=true; shift 2 ;;
    --enable-ssh) ssh_enable=true; shift ;;
    --settings-json) need_value "$@"; settings_json=$2; shift 2 ;;
    --replace) replace=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
[ "$(id -u)" -eq 0 ] || die "Run with sudo."
[ -e /etc/NIXOS ] || die "This installer requires an already installed NixOS."
[ "$(uname -m)" = x86_64 ] || die "Only x86_64 Intel/AMD is currently supported."
[ -d /sys/firmware/efi ] || die "Default installation requires UEFI. For BIOS, use the manual installation instructions."
case "$mode" in prepare|build|switch) ;; *) die "Invalid mode: $mode" ;; esac
[[ "$target" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Use an absolute target path without spaces."
[ "$target" != / ] || die "Target cannot be /."
target=$(realpath -m -- "$target")
[ "$target" != / ] || die "Target cannot resolve to /."
if [ -z "$username" ] || [ "$username" = root ]; then
  username=$(getent passwd 1000 | cut -d : -f 1)
fi
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Specify a valid --user."
getent passwd "$username" >/dev/null || die "Create the normal user first: $username"
uid=$(id -u "$username")
[ "$uid" -ge 1000 ] || die "Select a normal user, not a service account."
home_dir=$(getent passwd "$username" | cut -d : -f 6)
[[ "$home_dir" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Unsupported home directory path."
if [ -z "$hostname" ]; then hostname=$(hostname); fi
[[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || die "Invalid hostname."
if [ -z "$profile" ]; then
  if [ -t 0 ]; then
    printf 'Profile: 1) universal  2) huawei-matebook-d16 [1]: '
    read -r selection
    case "$selection" in 2) profile=huawei-matebook-d16 ;; ''|1) profile=universal ;; *) die "Unknown profile" ;; esac
  else profile=universal
  fi
fi
case "$profile" in universal|huawei-matebook-d16) ;; *) die "Unknown profile: $profile" ;; esac
if [ "$profile" = huawei-matebook-d16 ]; then
  grep -q AuthenticAMD /proc/cpuinfo || die "This Huawei profile is for AMD D16; use universal on Intel D16."
fi
for command in git nix nixos-generate-config python3 tar; do
  command -v "$command" >/dev/null || die "Missing command: $command (see README bootstrap command)."
done
settings_options=()
if [ -n "$settings_json" ]; then settings_options=(--options "$settings_json"); fi
python3 "$script_dir/render-settings.py" --validate-only "${settings_options[@]}"
if [ -n "$ssh_key" ]; then
  [ -f "$ssh_key" ] || die "Public key file does not exist."
  ssh-keygen -lf "$ssh_key" >/dev/null || die "Not a valid public SSH key."
  grep -q 'PRIVATE KEY' "$ssh_key" && die "Only a public .pub key is allowed."
fi
if [ -e "$target/bspwm-repo" ] || [ -e "$target/flake.nix" ]; then
  "$replace" || die "Target contains a repository/flake. Use --replace after reviewing its configuration."
fi
if "$replace" && [ -f "$target/local/settings.nix" ] && [ -n "$settings_json" ]; then
  die "Existing local settings are preserved; edit local/settings.nix instead of supplying --settings-json."
fi
mkdir -p "$target"
stage=$(mktemp -d "${target}.stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
if [ -n "$repo_url" ]; then
  git clone --depth 1 --branch "$ref" -- "$repo_url" "$stage/repo"
else
  source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  [ -f "$source_dir/flake.lock" ] || die "Run the installer from a complete checkout with flake.lock."
  mkdir "$stage/repo"
  cp -a "$source_dir/." "$stage/repo/"
fi
[ -f "$stage/repo/flake.lock" ] || die "Repository is missing its flake.lock."
mkdir "$stage/local"
if "$replace" && [ -d "$target/local" ]; then
  cp -a "$target/local/." "$stage/local/"
fi
if [ ! -f "$stage/local/hardware-configuration.nix" ]; then
  nixos-generate-config --show-hardware-config > "$stage/local/hardware-configuration.nix"
fi
state_version=$(nixos-version | cut -d . -f 1,2)
if [ -f /etc/nixos/configuration.nix ]; then
  old_state=$(sed -nE 's/^[[:space:]]*system\.stateVersion[[:space:]]*=[[:space:]]*"([0-9]{2}\.[0-9]{2})";.*/\1/p' /etc/nixos/configuration.nix | head -n 1)
  [ -z "$old_state" ] || state_version=$old_state
fi
[[ "$state_version" =~ ^[0-9]{2}\.[0-9]{2}$ ]] || die "Cannot detect system.stateVersion; use manual deployment."
if [ ! -f "$stage/local/settings.nix" ]; then
  python3 "$script_dir/render-settings.py" \
    --output "$stage/local/settings.nix" --user "$username" --uid "$uid" \
    --home "$home_dir" --hostname "$hostname" --state-version "$state_version" \
    --ssh "$ssh_enable" --ssh-key "$ssh_key" "${settings_options[@]}"
fi
[ -f "$stage/local/private.nix" ] || printf '{ ... }: {}\n' > "$stage/local/private.nix"
cat > "$stage/flake.nix" <<FLAKE
{
  description = "Local NixOS deployment ($profile)";
  inputs.bspwm.url = "path:$target/bspwm-repo";
  outputs = { bspwm, ... }: {
    nixosConfigurations.current = bspwm.lib.mkSystem {
      profile = "$profile";
      modules = [ ./local/hardware-configuration.nix ./local/settings.nix ./local/private.nix ];
    };
  };
}
FLAKE
backup="/var/backups/nixos-bspwm/$(date +%Y%m%d-%H%M%S)-$$"
install -d -m 700 "$backup"
tar --exclude=./result --exclude=./result-* -C "$target" -czf "$backup/config-before.tar.gz" .
readlink -f /run/current-system > "$backup/system-path.txt"
[ ! -e "$target/bspwm-repo" ] || mv -- "$target/bspwm-repo" "$backup/previous-repository"
[ ! -e "$target/local" ] || mv -- "$target/local" "$backup/previous-local"
mv -- "$stage/repo" "$target/bspwm-repo"
mv -- "$stage/local" "$target/local"
install -m 644 "$stage/flake.nix" "$target/flake.nix"
chmod 700 "$target/local"
mkdir -p /nix/var/nix/gcroots
ln -s "$(readlink -f /run/current-system)" "/nix/var/nix/gcroots/bspwm-before-$(basename "$backup")"
printf 'Profile: %s\nBackup: %s\nDeployment: %s\n' "$profile" "$backup" "$target"
nix --extra-experimental-features 'nix-command flakes' flake update --flake "path:$target" bspwm
case "$mode" in
  prepare) printf 'Prepared only. Next: sudo nixos-rebuild build --flake path:%s#current\n' "$target" ;;
  build|switch)
    NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild build --flake "path:$target#current"
    if [ "$mode" = switch ]; then
      NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake "path:$target#current"
      printf 'Configuration switched. Reboot when convenient to start the new login screen.\n'
    else
      printf 'Build succeeded. Apply: sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake path:%s#current\n' "$target"
    fi
    ;;
esac
