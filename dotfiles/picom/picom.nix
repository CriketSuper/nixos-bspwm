# /etc/nixos/dotfiles/picom/picom.nix
{ pkgs, ... }:

{
    services.picom = {
      enable = true;
      package = pkgs.picom;
  };
}
