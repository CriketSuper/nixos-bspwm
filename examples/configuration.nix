# Local settings for this PC. Edit this file, then: sudo nixos-rebuild switch
# This file and hardware-configuration.nix are excluded from Git.
{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./modules
    ./profiles/universal.nix # Change this ONE line to select the other profile.
  ];

  bspwmBuild = {
    username = "criket"; uid = 1000; homeDirectory = "/home/criket";
    homeStateVersion = "25.05";
    development.enable = true;
    virtualisation.enable = true;
    vpn.enable = true;
  };
  networking.hostName = "nixos-pc";
  time.timeZone = "Asia/Yekaterinburg";
  system.stateVersion = "26.05"; # Keep the ORIGINAL installation version.

  # SSH: change these native NixOS options here, without editing other modules.
  services.openssh = {
    enable = false;
    ports = [ 5555 ];
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      AllowUsers = [ "criket" ];
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };
  services.bspwmRdp = { enable = true; port = 3389; };

  # Extra packages can be added here. The desktop package lists are in packages/.
  environment.systemPackages = with pkgs; [ ];
}
