{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_pstate=active" ];
  hardware.firmware = [ pkgs.sof-firmware ];
  bspwmBuild = {
    hostName = "nixoscriket";
    ui = { battery = "BAT1"; adapter = "ACAD"; backlight = "amdgpu_bl1"; };
  };
  environment.systemPackages = with pkgs; [ xf86-video-amdgpu radeontop microcode-amd ];



  # The ACP controller on this MateBook runtime-suspends independently of
  # PipeWire. Waking it toggles the ES8316 speaker amplifier and produces a
  # loud pop. Keep this one controller and codec powered from their first udev
  # event; the rest of the machine keeps its normal runtime power management.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="backlight", KERNEL=="amdgpu_bl1", RUN+="${pkgs.coreutils}/bin/chgrp video /sys%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/brightness"
    ACTION=="add|change", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", ATTR{fn_lock_state}="1"
    ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15e2", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="i2c-ESSX8336:00", ATTR{power/control}="on"
  '';

  systemd.services.matebook-audio-init = {
    description = "Stabilize the MateBook ES8316 audio codec";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      # Reinforce the udev setting in case the device was already present when
      # the rules were reloaded.
      if [ -e /sys/bus/pci/devices/0000:03:00.5/power/control ]; then
        echo on > /sys/bus/pci/devices/0000:03:00.5/power/control
      fi

      for attempt in 1 2 3 4 5; do
        if ${pkgs.alsa-utils}/bin/amixer -c acp3xes83xx \
          sset 'DAC Soft Ramp' on >/dev/null 2>&1; then
          ${pkgs.alsa-utils}/bin/amixer -c acp3xes83xx \
            sset 'DAC Soft Ramp Rate' 3 >/dev/null
          exit 0
        fi
        sleep 1
      done
      exit 1
    '';
  };

  services.pipewire = {
    enable = true;




    wireplumber = {
      enable = true;

      # The ES8316 codec emits a pop when WirePlumber suspends and wakes the
      # built-in sink. Keep only this codec awake; HDMI and Bluetooth retain
      # their normal power-saving behaviour.
      extraConfig."51-matebook-es8316" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "node.name" = "~alsa_output.*platform-acp3x-es83xx.*";
              }
            ];
            actions.update-props = {
              "session.suspend-timeout-seconds" = 0;
              "node.pause-on-idle" = false;
            };
          }
        ];
      };
    };
  };

  # The UCM profile does not always enable both headphone DAC paths. Apply the
  # mixer state after PipeWire and WirePlumber are available.
  systemd.user.services.alsa-headphone-fix = {
    description = "Enable ES8316 headphone mixer paths";
    after = [ "pipewire.service" "wireplumber.service" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "alsa-headphone-fix" ''
        set -eu
        for attempt in 1 2 3 4 5; do
          if ${pkgs.alsa-utils}/bin/amixer -c acp3xes83xx \
            sset 'Right Headphone Mixer Right DAC' on >/dev/null 2>&1; then
            ${pkgs.alsa-utils}/bin/amixer -c acp3xes83xx \
              sset 'Left Headphone Mixer Left DAC' on >/dev/null
            exit 0
          fi
          sleep 1
        done
        exit 1
      '';
    };
  };
}
