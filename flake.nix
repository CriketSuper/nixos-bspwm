{
  description = "NixOS BSPWM desktop: Huawei MateBook D16 and generic x86_64";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/1bc55b9def8165e82073919945c3239903fe4dc2";
    home-manager.url = "github:nix-community/home-manager/db7d5e2332710f5abb088f6b5de927d7f9511b35";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, home-manager }:
    let
      profiles = {
        universal = ./profiles/universal.nix;
        huawei-matebook-d16 = ./profiles/huawei-matebook-d16.nix;
      };
      mkSystem = { profile ? "universal", system ? "x86_64-linux", modules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            home-manager.nixosModules.home-manager ./modules/default.nix
            (profiles.${profile} or (throw "Unknown profile: ${profile}"))
          ] ++ modules;
        };
      testHardware = {
        fileSystems."/" = { device = "/dev/disk/by-label/nixos-test-only"; fsType = "ext4"; };
        fileSystems."/boot" = { device = "/dev/disk/by-label/EFI-test-only"; fsType = "vfat"; };
        boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "sd_mod" ];
      };
    in {
      lib = { inherit mkSystem; };
      nixosModules = {
        default = ./modules/default.nix;
        universal = ./profiles/universal.nix;
        huawei-matebook-d16 = ./profiles/huawei-matebook-d16.nix;
      };
      # These build fixtures never contain the owner's disks or SSH keys.
      checks.x86_64-linux = nixpkgs.lib.mapAttrs (profile: _: (mkSystem {
        inherit profile; modules = [ testHardware ];
      }).config.system.build.toplevel) profiles;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
