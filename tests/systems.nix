# Build/evaluate fixtures only: these filesystems are NOT real hardware.
{ nixpkgs ? <nixpkgs> }:
let
  mkSystem = profile: import (nixpkgs + "/nixos") {
    system = "x86_64-linux";
    configuration = {
      imports = [ ../modules (../profiles + "/${profile}.nix") ];
      bspwmBuild = { username = "portableuser"; uid = 1007; homeDirectory = "/home/portableuser"; };
      fileSystems."/" = { device = "/dev/disk/by-label/test-only"; fsType = "ext4"; };
      fileSystems."/boot" = { device = "/dev/disk/by-label/efi-test-only"; fsType = "vfat"; };
      boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "sd_mod" ];
    };
  };
in {
  universal = mkSystem "universal";
  huawei-matebook-d16 = mkSystem "huawei-matebook-d16";
}
