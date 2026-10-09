# Local additions. Copy to /etc/nixos/local/private.nix; do not publish private data.
{ ... }: {
  # Optional RPM packages must be copied separately to the local machine.
  # bspwmBuild.vendor.chatgptSource = /var/lib/bspwm-vendor/ChatGPT-26.1002.52244-x86_64.rpm;
  # bspwmBuild.vendor.tgWsProxySource = /var/lib/bspwm-vendor/TgWsProxy_linux_amd64.rpm;
  # bspwmBuild.vendor.libreofficeSource = /var/lib/bspwm-vendor/LibreOffice_26.8.0_Linux_x86-64_rpm.tar.gz;
  # users.users.sshuser = {
  #   isNormalUser = true; homeMode = "0700"; initialHashedPassword = "!";
  #   openssh.authorizedKeys.keys = [ "ssh-ed25519 REPLACE_WITH_PUBLIC_KEY" ];
  # };
  # services.openssh.settings.AllowUsers = [ "youruser" "sshuser" ];
}
