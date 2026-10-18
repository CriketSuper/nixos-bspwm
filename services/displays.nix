{ config, pkgs, ... }:
{
  services.autorandr = {
    enable = true;
    defaultTarget = "horizontal";
    ignoreLid = true;
  };
  home-manager.users.${config.bspwmBuild.username} = {
    home.packages = [ pkgs.arandr pkgs.python3 pkgs.xset ];
    programs.autorandr = {
      enable = true;
      hooks.postswitch.bspwm = ''
        export PATH="${pkgs.lib.makeBinPath [ pkgs.bspwm pkgs.xrandr pkgs.xset pkgs.procps pkgs.polybar pkgs.feh pkgs.coreutils pkgs.gawk ]}:$PATH"
        if ${pkgs.bspwm}/bin/bspc query -M >/dev/null 2>&1; then
          ${pkgs.python3}/bin/python3 "$HOME/.config/scripts/sync-monitors.py"
        fi
      '';
    };
    xdg.configFile = {
      "scripts/sync-monitors.py".source = ../dotfiles/scripts/sync-monitors.py;
      "scripts/display-menu.sh" = {
        source = ../dotfiles/scripts/display-menu.sh;
        executable = true;
      };
    };
    home.file."nix-docs/monitors.md".source = ../docs/monitors.md;
  };
}
