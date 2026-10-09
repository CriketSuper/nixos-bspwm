{ config, lib, pkgs, ... }:

lib.mkIf config.bspwmBuild.virtualisation.enable {
  environment.systemPackages = with pkgs; [
    qemu					# Виртуализация
  ];
}
