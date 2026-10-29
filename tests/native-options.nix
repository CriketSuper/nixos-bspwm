{ nixpkgs ? <nixpkgs> }:
let
  cfg = (import (nixpkgs + "/nixos") {
    system = "x86_64-linux";
    configuration = { pkgs, ... }: {
      imports = [ ../modules ../profiles/universal.nix ];
      bspwmBuild.username = "alice";
      networking.hostName = "other-pc";
      time.timeZone = "Etc/UTC";
      system.stateVersion = "25.05";
      services.openssh = {
        enable = true;
        ports = [ 2222 ];
        settings = {
          PasswordAuthentication = true;
          PubkeyAuthentication = false;
          AllowUsers = [ "alice" "guest" ];
        };
      };
      environment.systemPackages = [ pkgs.hello ];
    };
  }).config;
in
assert builtins.elem "nixos-config=/etc/nixos/configuration.nix" cfg.nix.nixPath;
assert builtins.elem "nixpkgs=${builtins.storePath (import nixpkgs {}).path}" cfg.nix.nixPath;
assert cfg.nix.settings.nix-path == cfg.nix.nixPath;
assert cfg.boot.kernelPackages.kernel.drvPath == (import nixpkgs {}).linuxPackages.kernel.drvPath;
assert builtins.elem "graphical-session.target" cfg.systemd.user.targets.bspwm-rdp-session.bindsTo;
assert cfg.networking.hostName == "other-pc";
assert cfg.time.timeZone == "Etc/UTC";
assert cfg.system.stateVersion == "25.05";
assert cfg.services.openssh.enable;
assert cfg.services.openssh.ports == [ 2222 ];
assert cfg.services.openssh.settings.PasswordAuthentication;
assert !cfg.services.openssh.settings.PubkeyAuthentication;
assert cfg.services.openssh.settings.AllowUsers == [ "alice" "guest" ];
assert builtins.elem 2222 cfg.networking.firewall.allowedTCPPorts;
assert builtins.elem 3389 cfg.networking.firewall.allowedTCPPorts;
assert builtins.any (p: (p.pname or "") == "hello") cfg.environment.systemPackages;
assert builtins.any (p: (p.pname or "") == "tg-ws-proxy") cfg.environment.systemPackages;
assert builtins.any (p: (p.pname or "") == "chatgpt-desktop") cfg.environment.systemPackages;
{ passed = true; ssh = "native password settings"; }
