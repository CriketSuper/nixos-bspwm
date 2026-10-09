# Local additions. Copy to /etc/nixos/local/private.nix; do not publish private data.
{ ... }: {
  # Copy optional RPM files to /etc/nixos/local/vendor (outside the Git checkout).
  # bspwmBuild.vendor.chatgptSource = ./vendor/ChatGPT-26.1002.52244-x86_64.rpm;
  # bspwmBuild.vendor.tgWsProxySource = ./vendor/TgWsProxy_linux_amd64.rpm;
  # bspwmBuild.vendor.libreofficeSource = ./vendor/LibreOffice_26.8.0_Linux_x86-64_rpm.tar.gz;
  # users.users.sshuser = {
  #   isNormalUser = true; homeMode = "0700"; initialHashedPassword = "!";
  #   openssh.authorizedKeys.keys = [ "ssh-ed25519 REPLACE_WITH_PUBLIC_KEY" ];
  # };
  # services.openssh.settings.AllowUsers = [ "youruser" "sshuser" ];
}
