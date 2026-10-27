{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Оконный менеджер и компоненты
    bspwm                   # Граф оболочка BSPWM
    sxhkd                   # Шорткаты для BSPWM
    polybar                 # Верхнее меню для BSPWM
    picom                   # Композитор для отрисовки анимаций
    dunst                   # Демон для уведомлений
    libnotify				# Для проверки уведомлений
    rofi                    # Меню приложений
    rofi-calc               # Калькулятор
    rofi-emoji              # Эмодзи
    rofi-bluetooth          # Управление bluetooth в rofi
    jq                      # Сохранение положения окон bspwm
    feh                     # Для просмотра изображений
    nitrogen                # Выбор обоев из граф интерфейса

    # Терминалы
    alacritty               # Удобный терминал

    # Файловые менеджеры
    thunar                         # Файловый менеджер
    thunar-archive-plugin  # Поддержка архивов в thunar
    ranger                      # Консольный файловый менеджер

    # Браузеры
    tor-browser             # Браузер Тор
    chromium                # Браузер на основе хромиум

    # Медиа
    mpv                     # Просмотр видео
    vlc                                         # Медиа-плеер
    audacity                # Работа со звуком
    obs-studio              # Софт для записи видео
    kdePackages.kdenlive    # Монтаж видео
    gthumb                  # Просмотр и редактирование изображений
    flameshot               # Программа для скриншотов
    scrot                   # Консольный софт для скриншотов

    # Офисный пакет и полезные приложения
    (callPackage ./obsidian.nix {}) # Работа с заметками
    anki                    # Программа для карточек
    homebank                # Отслеживание финансов
    calcurse                # Консольный календарь
    keepassxc               # Защищенный менеджер паролей
    telegram-desktop        # Мессенджер
    deluge-gtk              # Торрент клиент
    pinta                   # Софт для рисования

    # Графические утилиты
    gpick                   # Определить цвета
    lxappearance            # Управление темами, иконками
    papirus-icon-theme      # Пак иконок для окружения
    imagemagick             # Консольный команды для редактирования изображений
    networkmanagerapplet    # Граф редактор сетей
    polkit_gnome            # Запрос прав администратора в BSPWM
    filezilla               # Работа с FTP из граф среды
    sqlitebrowser           # Работа с SQLite базами

    # Системные GUI утилиты
    gparted                 # Работа с носителями в системе
    gnome-disk-utility      # Просмотр и редактирование дисков
    bleachbit               # Софт для очищения системы
    bluetuith               # TUI менеджер для bluetoth

    # Дополнительные GUI-пакеты
    screenkey               # Вывод нажатий клавиатуры на экран
    hexyl                   # Hex дампер
    hyx                     # hex редактор
  ];
}
