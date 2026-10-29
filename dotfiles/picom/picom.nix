# /etc/nixos/dotfiles/picom/picom.nix
{ pkgs, ... }:

{
    services.picom = {
      enable = true;
      package = pkgs.picom;
  };
  # The RDP session starts a separate XRender compositor for its virtual GPU.
  systemd.user.services.picom.Unit.ConditionEnvironment = "!BSPWM_RDP_SESSION=1";
}
