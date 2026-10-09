{ config, lib, pkgs, ... }:
let v = config.bspwmBuild.vendor; in {
  environment.systemPackages = with pkgs; [
    windterm seafile-client thunderbird codex bubblewrap
  ] ++ lib.optional (v.tgWsProxySource != null)
    (callPackage ./tg-ws-proxy.nix { src = v.tgWsProxySource; })
    ++ lib.optional (v.chatgptSource != null)
    (callPackage ./chatgpt-desktop.nix { src = v.chatgptSource; })
    ++ [ (if v.libreofficeSource == null then libreoffice-fresh
          else import ./libreoffice-rpm.nix { inherit pkgs; src = v.libreofficeSource; }) ];
}
