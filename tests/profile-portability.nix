# Evaluation checks for actual hardware/user differences, not a deployable system.
{ repo }:
let
  hardware = {
    fileSystems."/" = { device = "/dev/disk/by-label/test-only"; fsType = "ext4"; };
    fileSystems."/boot" = { device = "/dev/disk/by-label/efi-test-only"; fsType = "vfat"; };
  };
  universal = (repo.lib.mkSystem {
    modules = [ hardware {
      bspwmBuild = { username = "portableuser"; uid = 1007; homeDirectory = "/home/portableuser"; };
    } ];
  }).config;
  huawei = (repo.lib.mkSystem { profile = "huawei-matebook-d16"; modules = [ hardware ]; }).config;
in
assert universal.users.users.portableuser.uid == 1007;
assert universal.home-manager.users.portableuser.home.homeDirectory == "/home/portableuser";
assert universal.systemd.services.hiddify-gui.serviceConfig.User == "portableuser";
assert universal.systemd.services.hiddify-gui.environment.XAUTHORITY == "/home/portableuser/.Xauthority";
assert universal.systemd.services.hiddify-gui.environment.XDG_RUNTIME_DIR == "/run/user/1007";
assert !universal.services.openssh.enable;
assert universal.services.xrdp.enable && huawei.services.xrdp.enable;
assert universal.users.groups.rdp-users.members == [ "portableuser" ];
assert !universal.security.pam.services.xrdp-sesman.allowNullPassword;
assert !universal.virtualisation.virtualbox.host.enable;
assert !huawei.virtualisation.virtualbox.host.enable;
assert !universal.systemd.services ? matebook-audio-init;
assert !(builtins.elem "amd_pstate=active" universal.boot.kernelParams);
assert universal.bspwmBuild.ui.backlight == null;
assert builtins.all (rule: builtins.all (command: !(builtins.isAttrs command && command.command == "ALL" && builtins.elem "NOPASSWD" (command.options or []))) rule.commands) universal.security.sudo.extraRules;
assert huawei.systemd.services ? matebook-audio-init;
assert builtins.elem "amd_pstate=active" huawei.boot.kernelParams;
assert huawei.bspwmBuild.ui.backlight == "amdgpu_bl1";
assert huawei.services.pipewire.wireplumber.extraConfig ? "51-matebook-es8316";
{ passed = true; profiles = [ "universal" "huawei-matebook-d16" ]; customUid = 1007; }
