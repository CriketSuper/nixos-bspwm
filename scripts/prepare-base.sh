#!/usr/bin/env bash
# Optional helper for a freshly formatted and mounted target in the live ISO.
set -euo pipefail
export LC_ALL=C LANGUAGE=C
root=${1:-/mnt}
username=${2:-criket}
[ "$(id -u)" -eq 0 ] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || { printf 'Invalid user name.\n' >&2; exit 1; }
root=$(realpath -e -- "$root")
if [ "$root" = / ] || ! mountpoint -q "$root" || ! mountpoint -q "$root/boot"; then
  printf 'Mount the new root filesystem and its EFI partition first.\n' >&2; exit 1;
fi
[ -d /sys/firmware/efi ] || { printf 'Boot the ISO in UEFI mode.\n' >&2; exit 1; }
[ ! -f "$root/etc/os-release" ] || { printf 'This helper is only for a fresh target, not an installed OS.\n' >&2; exit 1; }
nixos-generate-config --root "$root"
cat > "$root/etc/nixos/configuration.nix" <<EOF
{ pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  hardware.enableRedistributableFirmware = true;
  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  users.users.$username = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  environment.systemPackages = with pkgs; [ git python3 dialog nano ];
  system.stateVersion = "26.05";
}
EOF
printf 'Base files ready. Run: nixos-install --root %s\nThen set the normal user password with nixos-enter --root %s -c "passwd %s"\n' "$root" "$root" "$username"
