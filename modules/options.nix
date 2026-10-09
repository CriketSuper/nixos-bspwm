{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.bspwmBuild;
in {
  options.bspwmBuild = {
    username = mkOption { type = types.str; default = "criket"; };
    uid = mkOption { type = types.int; default = 1000; };
    homeDirectory = mkOption { type = types.str; default = "/home/${cfg.username}"; };
    stateVersion = mkOption { type = types.str; default = "26.05"; };
    homeStateVersion = mkOption { type = types.str; default = "25.05"; };
    timeZone = mkOption { type = types.str; default = "Asia/Yekaterinburg"; };
    hostName = mkOption { type = types.str; default = "nixos-bspwm"; };
    development.enable = mkOption { type = types.bool; default = true; };
    virtualisation.enable = mkOption { type = types.bool; default = true; };
    vpn.enable = mkOption { type = types.bool; default = true; };
    ssh = {
      enable = mkOption { type = types.bool; default = false; };
      port = mkOption { type = types.port; default = 5555; };
      passwordAuthentication = mkOption { type = types.bool; default = false; };
      authorizedKeys = mkOption { type = types.listOf types.str; default = []; };
    };
    vendor = {
      chatgptSource = mkOption { type = types.nullOr types.path; default = null; };
      libreofficeSource = mkOption { type = types.nullOr types.path; default = null; };
      tgWsProxySource = mkOption { type = types.nullOr types.path; default = null; };
    };
    ui = {
      battery = mkOption { type = types.nullOr types.str; default = null; };
      adapter = mkOption { type = types.nullOr types.str; default = null; };
      backlight = mkOption { type = types.nullOr types.str; default = null; };
    };
  };
  config.assertions = [
    { assertion = builtins.match "[a-z_][a-z0-9_-]*" cfg.username != null;
      message = "bspwmBuild.username must be a valid Linux account name."; }
    { assertion = cfg.uid >= 1000;
      message = "The BSPWM account must have a normal-user UID (>= 1000)."; }
  ];
}
