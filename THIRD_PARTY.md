# Происхождение компонентов

Этот проект — форк [Zproger/bspwm-dotfiles](https://github.com/Zproger/bspwm-dotfiles), полностью перенесённый с Arch Linux на NixOS. Zproger — автор оригинального проекта для Arch Linux. Nix-конфигурация, Home Manager, установщик и дополнительные возможности разработаны в этом форке. Исходное уведомление MIT сохранено в LICENSE.
Внесены изменения для NixOS, аппаратного профиля Huawei, блокировки, ассоциаций файлов, VPN и мониторов.
XSecureLock и LightDM GTK Greeter загружаются из Nixpkgs и патчатся при сборке; они сохраняют собственные лицензии. Исходные программы не включены в этот репозиторий.
Внешние приложения и шрифты имеют собственные лицензии; разрешение unfree в Nix не означает разрешение на перепубликацию RPM.
Изображения имеют отдельные условия распространения. Источники NixOS-обоев перечислены в [NIXOS-SOURCES.md](dotfiles/wallpapers/NIXOS-SOURCES.md).

`packages/assets/obsidian-logo-gradient.svg` — неизменённая официальная иконка [Obsidian](https://obsidian.md/images/obsidian-logo-gradient.svg), SHA-256 `119b01b96c99f736098742c329f440313b6763bd2aea22cafe08179699431280`. Используется только для значка приложения; права на название и изображение принадлежат Obsidian, общая MIT-лицензия форка на них не распространяется. Файл совпадает с иконкой пакета Obsidian в Nixpkgs 26.05.
TG WS Proxy 1.10.4 загружается из [официального выпуска Flowseal](https://github.com/Flowseal/tg-ws-proxy/releases/tag/v1.10.4) с проверкой SHA-256; RPM не хранится в Git.
