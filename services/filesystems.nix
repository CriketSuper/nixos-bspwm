{ config, pkgs, ... }:

{
  programs.fuse.userAllowOther = true;  # Для sshfs и других FUSE-файловых систем
}
