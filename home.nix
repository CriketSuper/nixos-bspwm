{ config, lib, ... }:

{
  # Home Manager is provided by the locked flake input.

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users.${config.bspwmBuild.username} = { config, osConfig, pkgs, ... }:
      let
        batteryAlert = pkgs.writeShellApplication {
          name = "battery-alert";
          runtimeInputs = with pkgs; [ coreutils findutils gnused libnotify ];
          text = builtins.readFile ./dotfiles/scripts/battery-alert.sh;
        };
      in {
      imports = [
        ./dotfiles/alacritty/alacritty.nix
        ./dotfiles/dunst/dunst.nix
        ./dotfiles/picom/picom.nix
        ./dotfiles/fish/fish.nix
        ./dotfiles/mime-apps.nix
      ];

      home = {
        username = osConfig.bspwmBuild.username;
        homeDirectory = osConfig.bspwmBuild.homeDirectory;
        stateVersion = osConfig.bspwmBuild.homeStateVersion;

        packages = with pkgs; [
          fastfetch
          fish
          polybar
          (rofi.override { plugins = [ rofi-calc rofi-emoji ]; })
          feh
          xrandr
          xrdb
          xclip
          gnused
          coreutils
          alsa-utils
          psmisc
          brightnessctl
          libnotify
          gpick
          flameshot
        ];

        sessionVariables = {
          BSPWM_BATTERY = if osConfig.bspwmBuild.ui.battery == null then "" else osConfig.bspwmBuild.ui.battery;
          BSPWM_ADAPTER = if osConfig.bspwmBuild.ui.adapter == null then "" else osConfig.bspwmBuild.ui.adapter;
          BSPWM_BACKLIGHT = if osConfig.bspwmBuild.ui.backlight == null then "" else osConfig.bspwmBuild.ui.backlight;
          EDITOR = "micro";
          VISUAL = "micro";
          BROWSER = "${pkgs.firefox}/bin/firefox";
          TERMINAL = "${pkgs.alacritty}/bin/alacritty";
        };

        pointerCursor = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
          size = 24;
          gtk.enable = true;
          x11.enable = true;
        };

        file = {
          "nix-docs/rdp.md".source = ./docs/rdp.md;
          "nix-docs/installation.md".source = ./docs/installation.md;
          "nix-docs/shortcuts.md".source = ./docs/shortcuts.md;
          "nix-docs/openvpn.md".source = ./docs/openvpn.md;
          "nix-docs/chatgpt-update.md".source = ./docs/chatgpt-update.md;
          "nix-docs/vpn.md".source = ./docs/vpn.md;
          "nix-docs/ssh-access.md".source = ./docs/ssh-access.md;
          "nix-docs/vpn-fingerprints.md".source = ./docs/vpn-fingerprints.md;
          "Pictures/wallpapers" = {
            source = ./dotfiles/wallpapers;
            recursive = true;
          };
        };
      };

      xresources.extraConfig = builtins.readFile ./dotfiles/Xresources;

      gtk = {
        enable = true;
        theme.name = "Adwaita-dark";
        gtk4.theme = config.gtk.theme;
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        font = {
          name = "Noto Sans";
          size = 11;
        };
      };

      xdg.configFile = {
        "bspwm/bspwmrc" = {
          source = ./dotfiles/bspwm/bspwmrc;
          executable = true;
        };
        "sxhkd/sxhkdrc".source = ./dotfiles/sxhkd/sxhkdrc;
        "scripts/battery-alert.sh" = {
          source = ./dotfiles/scripts/battery-alert.sh;
          executable = true;
        };
        "scripts/brightness.sh" = {
          source = ./dotfiles/scripts/brightness.sh;
          executable = true;
        };
        "scripts/calculator.sh" = {
          source = ./dotfiles/scripts/calculator.sh;
          executable = true;
        };
        "scripts/color-picker.sh" = {
          source = ./dotfiles/scripts/color-picker.sh;
          executable = true;
        };
        "scripts/dual_monitors.sh" = {
          source = ./dotfiles/scripts/dual_monitors.sh;
          executable = true;
        };
        "scripts/frozen-window.sh" = {
          source = ./dotfiles/scripts/frozen-window.sh;
          executable = true;
        };
        "scripts/network-status.sh" = {
          source = ./dotfiles/scripts/network-status.sh;
          executable = true;
        };
        "scripts/polybar-volume.sh" = {
          source = ./dotfiles/scripts/polybar-volume.sh;
          executable = true;
        };
        "scripts/power-menu.sh" = {
          source = ./dotfiles/scripts/power-menu.sh;
          executable = true;
        };
        "scripts/random_wallpaper.sh" = {
          source = ./dotfiles/scripts/random_wallpaper.sh;
          executable = true;
        };
        "scripts/screen-lock.sh" = {
          source = ./dotfiles/scripts/screen-lock.sh;
          executable = true;
        };
        "scripts/toggle-polybar.sh" = {
          source = ./dotfiles/scripts/toggle-polybar.sh;
          executable = true;
        };
        "scripts/volume.sh" = {
          source = ./dotfiles/scripts/volume.sh;
          executable = true;
        };
        "polybar/config.ini".source = ./dotfiles/polybar/config.ini;
        "polybar/colors.ini".source = ./dotfiles/polybar/colors.ini;
        "polybar/modules.ini".source = ./dotfiles/polybar/modules.ini;
        "polybar/launch.sh" = {
          source = ./dotfiles/polybar/launch.sh;
          executable = true;
        };
        "rofi" = {
          source = ./dotfiles/rofi;
          recursive = true;
        };
        "picom/picom.conf".source =
          ./dotfiles/picom/style-simple/picom.conf;
        "picom/picom-animations.conf".source =
          ./dotfiles/picom/picom_animations.conf;
      };

      systemd.user.services.battery-alert = {
        Unit = {
          Description = "Notify when the laptop battery is low";
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${batteryAlert}/bin/battery-alert";
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.polkit-gnome-agent = {
        Unit = {
          Description = "GNOME Polkit authentication agent";
          After = [ "graphical-session-pre.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart =
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
