{ config, lib, pkgs, ... }:

let
  cfg = config.bspwmBuild;
  hiddifyPackage = pkgs.callPackage ../packages/hiddify.nix {};
  hiddifyLaunch = pkgs.writeShellApplication {
    name = "hiddify";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if systemctl is-active --quiet hiddify-gui.service; then
        exec ${hiddifyPackage}/bin/hiddify
      fi
      systemctl start hiddify-gui.service
    '';
  };
  hiddifyDesktop = pkgs.makeDesktopItem {
    name = "hiddify";
    desktopName = "Hiddify";
    comment = "VLESS VPN client";
    exec = "hiddify";
    icon = "hiddify";
    categories = [ "Network" ];
    startupWMClass = "app.hiddify.com";
  };
  hiddify = pkgs.symlinkJoin {
    name = "hiddify-launcher";
    paths = [ hiddifyLaunch hiddifyDesktop ];
    postBuild = ''
      mkdir -p "$out/share/icons/hicolor/256x256/apps"
      ln -s ${hiddifyPackage}/share/icons/hicolor/256x256/apps/hiddify.png "$out/share/icons/hicolor/256x256/apps/hiddify.png"
    '';
  };
  v2rayaLaunch = pkgs.writeShellApplication {
    name = "v2raya-ui";
    runtimeInputs = [ pkgs.systemd pkgs.xdg-utils ];
    text = ''
      systemctl start v2raya.service
      xdg-open http://127.0.0.1:2017
    '';
  };
  v2rayaDesktop = pkgs.makeDesktopItem {
    name = "v2raya-ui";
    desktopName = "v2rayA";
    comment = "Manage the Xray VPN connection";
    exec = "v2raya-ui";
    icon = "network-vpn";
    categories = [ "Network" ];
  };
  xrayAssets = pkgs.symlinkJoin {
    name = "xray-routing-assets";
    paths = [ pkgs.v2ray-geoip pkgs.v2ray-domain-list-community ];
  };
in
lib.mkIf cfg.vpn.enable {
  environment.systemPackages = [ hiddify v2rayaLaunch v2rayaDesktop ];

  # Keep the management UI local and use the Xray core for VLESS.
  services.v2raya = {
    enable = true;
    cliPackage = pkgs.xray;
  };
  systemd.services.v2raya.environment = {
    V2RAYA_ADDRESS = "127.0.0.1:2017";
    V2RAYA_V2RAY_ASSETSDIR = "${xrayAssets}/share/v2ray";
    V2RAYA_V2RAY_BIN = "${pkgs.xray}/bin/xray";
  };
  systemd.services.v2raya.path = [ pkgs.kmod ];
  systemd.services.v2raya.serviceConfig.RestartSec = 3;
  boot.kernelModules = [ "xt_TPROXY" ];

  # Hiddify embeds its network core in the GUI process on Linux.
  # Give this user's process only the required network capabilities.
  # Start it on demand; switching clients shuts down the other core.
  systemd.services.hiddify-gui = {
    description = "Hiddify VPN for the local X11 session";
    after = [ "display-manager.service" "network.target" "v2raya.service" ];
    conflicts = [ "v2raya.service" ];
    path = with pkgs; [ iproute2 systemd coreutils xdg-utils ];
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "${cfg.homeDirectory}/.Xauthority";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString cfg.uid}/bus";
      XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
    };
    serviceConfig = {
      ExecStart = "${hiddifyPackage}/bin/hiddify";
      WorkingDirectory = cfg.homeDirectory;
      User = cfg.username;
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      NoNewPrivileges = true;
      TimeoutStopSec = 15;
    };
  };

  # Allow only these fixed units to be controlled by the local active user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units" &&
          subject.user === ${builtins.toJSON cfg.username} && subject.active && subject.local &&
          ["hiddify-gui.service", "v2raya.service"].indexOf(action.lookup("unit")) !== -1 &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) !== -1) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.amnezia-vpn.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
}
