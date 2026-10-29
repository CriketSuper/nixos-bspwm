{ config, lib, pkgs, ... }:

lib.mkIf config.bspwmBuild.development.enable {
  environment.systemPackages = with pkgs; [
    # Редакторы и IDE
    neovim                  # Текстовый редактор
    micro                   # Текстовый редактор
    nano                    # Текстовый редактор
    vscode                  # Редактор кода
    dbeaver-bin             # Database client present in the original laptop setup

    # Языки программирования и компиляторы
    nodejs_24               # NodeJS
    go                      # Для языка Go
    gcc                     # Для языка C
    clang                   # Для языка C
    rustc                   # Для языка Rust
    python313				# Python 3.13

    # Системные сборки
    gnumake                 # Поддержка make
    cmake                   # Дополнительно для make
    automake                # Автоматическое создание Makefile
    autoconf                # Дополнительно для make

    # Системы контроля версий
    lazygit                 # Удобный интерфейс для управления git

    # Контейнеризация и виртуализация
    docker-compose          # + к докеру
    lazydocker              # Удобный интерфейс для управления docker

    # Сетевые инструменты
    wireshark               # Перехват и анализ сетевых пакетов
    netcat-gnu              # Утилита для работы с сетью
    openvpn                 # Поддержка протокола OpenVPN
    networkmanager-openvpn  # OpenVPN плагит для NM
    tor                     # Для работы Тора
    strongswan
    xl2tpd
    ppp
    wireguard-tools
    busybox

    # Утилиты разработчика
    shellcheck              # Анализатор оболочки
    cloc                    # Подсчет количества строк кода
    yt-dlp                  # Скачивание видео с ютуб
    cowsay                  # Вывод текста с ASCII артами
    bat                     # Улучшенная версия cat
    lsd                     # Расширенная версия ls
    tree                    # Отображает дерево

    # Документация
    evince                  # Читалка для PDF
    zathura                 # Просмотр PDF
  ];
}
