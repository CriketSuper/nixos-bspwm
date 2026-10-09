{ pkgs, ... }:

let
  lockPackage = (pkgs.xsecurelock.override { withXscreensaver = false; }).overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [ "--with-mpv=${pkgs.mpv}/bin/mpv" ];
nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.python3 ];
    postPatch = (old.postPatch or "") + ''
      cp ${../dotfiles/lockscreen/lock-card.c} helpers/criket_lock_card.c
      ${pkgs.python3}/bin/python3 ${../dotfiles/lockscreen/lock-card-patch.py}
    '';
    postInstall = (old.postInstall or "") + ''
      wrapProgram "$out/libexec/xsecurelock/saver_mpv" --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.findutils pkgs.gnused ]}
    '';
  });
  loginGreeter = pkgs.lightdm-gtk-greeter.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.python3 ];
    buildInputs = old.buildInputs ++ [ pkgs.libxklavier ];
    configureFlags = old.configureFlags ++ [ "--with-libxklavier" ];
    postPatch = (old.postPatch or "") + ''
      ${pkgs.python3}/bin/python3 ${../dotfiles/lightdm/greeter-password-toggle.py}
    '';
  });
  loginGreeterFiles = pkgs.runCommand "lightdm-gtk-greeter-password-toggle" {} ''
    mkdir -p "$out"
    ln -s ${loginGreeter}/share/xgreeters/lightdm-gtk-greeter.desktop "$out/lightdm-gtk-greeter.desktop"
  '';
in
{
  security.pam.services.i3lock.enable = true;
  security.pam.services.xsecurelock.enable = true;
  environment.systemPackages = [ lockPackage ];
  # Keep this session running; load the new greeter at the next display-manager start.
  systemd.services.display-manager.restartIfChanged = false;


  services.xserver = {
    enable = true;
    xkb = {
      layout = "us,ru";
      options = "grp:alt_shift_toggle";
    };

    desktopManager.xterm.enable = false;
    windowManager.bspwm.enable = true;
    displayManager.lightdm = {
      enable = true;
      greeter.package = loginGreeterFiles;
      greeter.name = "lightdm-gtk-greeter";
      background = ./../dotfiles/wallpapers/5521453.jpg;
      greeters.slick.enable = false;
      greeters.gtk = {
        enable = true;
        indicators = [ "~clock" "~spacer" "~layout" "~session" "~power" ];
        theme = {
          name = "CriketGlass";
          package = pkgs.runCommand "lightdm-criket-glass-theme" { } ''
            mkdir -p "$out/share/themes/CriketGlass/gtk-3.0"
            cp ${../dotfiles/lightdm/gtk.css} "$out/share/themes/CriketGlass/gtk-3.0/gtk.css"
          '';
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        extraConfig = ''
          keyboard-layouts = us;ru
          user-background = false
          position = 50%,center 50%,center
        '';
      };
    };
  };

  services.libinput.enable = true;
}
