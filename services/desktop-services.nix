{ config, pkgs, ... }:

{
  programs.dconf.enable = true;      # GTK/Home Manager settings over D-Bus
  services.clipmenu.enable = true;  # История буфера обмена для Rofi
    services.gvfs.enable = true;     # Для Thunar, монтирования устройств
    services.tumbler.enable = true;  # Миниатюры в файловых менеджерах
  services.udisks2.enable = true;  # Автомонтирование USB
    services.upower.enable = true;   # Управление питанием
}
