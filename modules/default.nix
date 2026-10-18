{ config, lib, pkgs, ... }:
let cfg = config.bspwmBuild; in {
  imports = [
    ./options.nix
    ../users.nix
    ../packages/desktop.nix ../packages/extra-apps.nix
    ../packages/system.nix ../packages/dev.nix ../packages/virtualization.nix
    ../services/audio.nix ../services/bluetooth.nix
    ../services/network.nix ../services/xserver.nix ../services/displays.nix
    ../services/git.nix ../services/desktop-services.nix ../services/filesystems.nix
    ../services/vpn.nix ../services/rdp.nix ../home.nix
  ];
  services.bspwmRdp = { enable = lib.mkDefault true; allowedUsers = [ cfg.username ]; };
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  hardware.enableRedistributableFirmware = true;
  boot.loader.systemd-boot = { enable = lib.mkDefault true; configurationLimit = 2; };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  time.timeZone = cfg.timeZone;
  i18n.defaultLocale = "ru_RU.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS" "LC_IDENTIFICATION" "LC_MEASUREMENT" "LC_MONETARY" "LC_NAME"
    "LC_NUMERIC" "LC_PAPER" "LC_TELEPHONE" "LC_TIME"
  ] (_: "ru_RU.UTF-8");
  fonts.packages = with pkgs; [
    font-awesome unifont jetbrains-mono nerd-fonts.jetbrains-mono fira-code
    symbola material-design-icons noto-fonts noto-fonts-color-emoji
  ];
  services.printing.enable = true;
  programs.firefox.enable = true;
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc.lib gcc.cc.lib glibc zlib ];
  };
  virtualisation.docker.enable = cfg.virtualisation.enable;
  system.stateVersion = cfg.stateVersion;
}
