{ config, lib, pkgs, ... }:
let cfg = config.bspwmBuild; in {
  users.users.${cfg.username} = {
    isNormalUser = true;
    uid = cfg.uid;
    home = cfg.homeDirectory;
    homeMode = "0700";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ]
      ++ lib.optionals cfg.virtualisation.enable [ "docker" "libvirt" ]
      ++ lib.optional cfg.development.enable "wireshark";
    packages = [ pkgs.tree ];
    openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
  };
}
