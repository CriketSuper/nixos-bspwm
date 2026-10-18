{ config, lib, pkgs, ... }:
let
  cfg = config.services.bspwmRdp;
  desktop = pkgs.writeShellApplication {
    name = "bspwm-rdp-desktop";
    runtimeInputs = with pkgs; [ bspwm sxhkd systemd coreutils rofi setxkbmap xrdb xsetroot dunst ];
    text = ''
      # The common desktop helpers assume one graphical session per user.
      # Give a clear explanation instead of killing another session's panel.
      sessions=$(loginctl show-user "$(id -u)" -p Sessions --value 2>/dev/null || true)
      for session in $sessions; do
        session_type=$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)
        remote=$(loginctl show-session "$session" -p Remote --value 2>/dev/null || true)
        state=$(loginctl show-session "$session" -p State --value 2>/dev/null || true)
        if [ "$session_type" = x11 ] && [ "$remote" = no ] && [ "$state" != closing ]; then
          rofi -e 'Локальный рабочий стол этого пользователя уже открыт. Выйдите из системы на ноутбуке и подключитесь снова.'
          exit 1
        fi
      done
      setxkbmap -layout us,ru -option grp:alt_shift_toggle
      dunst &
      notification_pid=$!
      ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &
      agent_pid=$!
      cleanup() {
        kill "$notification_pid" "$agent_pid" 2>/dev/null || true
      }
      trap cleanup EXIT
      bspwm &
      wm_pid=$!
      trap 'kill "$wm_pid" 2>/dev/null || true' HUP INT TERM
      wait "$wm_pid"
    '';
  };
  session = pkgs.writeShellScript "bspwm-rdp-session" ''
    unset DBUS_SESSION_BUS_ADDRESS SESSION_MANAGER
    export XDG_SESSION_TYPE=x11
    export XDG_CURRENT_DESKTOP=bspwm
    export XDG_SESSION_DESKTOP=bspwm
    export BSPWM_RDP_SESSION=1
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${desktop}/bin/bspwm-rdp-desktop
  '';
in {
  options.services.bspwmRdp = {
    enable = lib.mkEnableOption "BSPWM desktop over xrdp";
    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Existing normal users allowed to log in over RDP.";
    };
    port = lib.mkOption { type = lib.types.port; default = 3389; };
    openFirewall = lib.mkOption { type = lib.types.bool; default = true; };
  };
  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.allowedUsers != [] && builtins.all (name:
        name != "root" && builtins.hasAttr name config.users.users && config.users.users.${name}.isNormalUser
      ) cfg.allowedUsers;
      message = "services.bspwmRdp.allowedUsers must list existing normal accounts.";
    }];
    services.xrdp = {
      enable = true;
      inherit (cfg) port openFirewall;
      defaultWindowManager = "exec ${session}";
      audio.enable = false; # The NixOS module's audio backend does not support PipeWire.
      extraConfDirCommands = ''
        substituteInPlace "$out/sesman.ini" \
          --replace-fail 'AllowRootLogin=true' 'AllowRootLogin=false' \
          --replace-fail 'TerminalServerUsers=tsusers' 'TerminalServerUsers=rdp-users' \
          --replace-fail 'AlwaysGroupCheck=false' 'AlwaysGroupCheck=true'
        # Only offer the configured Xorg desktop, not arbitrary VNC gateways.
        ${pkgs.gawk}/bin/awk '
          /^\[/ { section = $0 }
          section == "[Globals]" || section == "[Logging]" ||
          section == "[LoggingPerLogger]" || section == "[Channels]" ||
          section == "[Xorg]" { print }
        ' "$out/xrdp.ini" > "$out/xrdp.ini.tmp"
        mv "$out/xrdp.ini.tmp" "$out/xrdp.ini"
      '';
    };
    users.groups.rdp-users.members = cfg.allowedUsers;
    security.pam.services.xrdp-sesman.allowNullPassword = lib.mkForce false;
  };
}
