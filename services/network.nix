{ config, lib, pkgs, ... }:
let cfg = config.bspwmBuild; in {
  networking.hostName = lib.mkDefault "nixos-bspwm";
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
  networking.firewall.enable = true;
  services.openssh = {
    # All of these can be overridden normally in configuration.nix.
    enable = lib.mkDefault false;
    openFirewall = lib.mkDefault true;
    settings = {
      PermitRootLogin = lib.mkDefault "no";
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false;
      AllowUsers = lib.mkDefault [ cfg.username ];
    };
  };
}
