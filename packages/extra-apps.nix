{ config, pkgs, ... }:
let v = config.bspwmBuild.vendor; in {
  environment.systemPackages = with pkgs; [
    windterm seafile-client thunderbird codex bubblewrap
  ] ++ [ (callPackage ./tg-ws-proxy.nix
    { src = v.tgWsProxySource; }) ]
    ++ [ (callPackage ./chatgpt-desktop.nix { src = v.chatgptSource; }) ]
    ++ [ (import ./libreoffice-rpm.nix { inherit pkgs; src = v.libreofficeSource; }) ];
}
