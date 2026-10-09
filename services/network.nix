{ config, lib, pkgs, ... }:
let cfg = config.bspwmBuild; in {
  networking.hostName = lib.mkDefault cfg.hostName;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
  networking.firewall.enable = true;
  services.openssh = lib.mkIf cfg.ssh.enable {
    enable = true;
    openFirewall = true;
    ports = [ cfg.ssh.port ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = cfg.ssh.passwordAuthentication;
      KbdInteractiveAuthentication = false;
      AllowUsers = [ cfg.username ];
    };
  };
}
