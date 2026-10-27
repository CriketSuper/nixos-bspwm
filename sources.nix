# Home Manager is a regular NixOS module, not a separate rebuild command.
# Nixpkgs comes from the standard NixOS 26.05 channel (<nixpkgs>).
{
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/db7d5e2332710f5abb088f6b5de927d7f9511b35.tar.gz";
    sha256 = "sha256-f+kOxEmOUnQazVAmGg0i8hzwgd1kX/geY+k/Dpheye8=";
  };
}
