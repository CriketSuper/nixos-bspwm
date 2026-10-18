{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    micro                   # Keep the default editor available without development tools
    # Аудио-видео система
    alsa-utils              # Утилита для звука
    alsa-plugins            # Плагины для Alsa
    pavucontrol             # Микшер для звука
  crosspipe               # Графическая коммутация PipeWire
    cava                    # Вывод спектра для музыки
    ffmpeg                  # Утилита для работы с медиа
    ffmpegthumbnailer       # Создает миниатюры в thunar

  # Для кофигурирования окружения пользователя
  # home-manager
  home-manager

    # Графические драйверы и утилиты

    # Системные мониторы
    htop                    # Системный монитор
    btop                    # Системный монитор

    # Управление питанием и дисплеем
    brightnessctl           # Для настройки яркости

    # Файловые системы и архивы
    tumbler                 # Создает миниатбры в thunar
    gzip                    # Работа с архивами
    p7zip                   # Работа с архивами
    zip                     # Работа с архивами
    unrar                   # Работа с архивами
    unzip                   # Работа с архивами
    xarchiver               # Работа с архивами

    # Сеть и bluetooth
    bluez-tools             # Пакет для блютуза
    sshfs                   # Монтирование удалённых SSH каталогов локально
    openssh                 # Для работы с ssh
    albedo                  # Получить зеркала

    # Системные утилиты
    usbutils                # Утилита для работы с usb
    fakeroot                # Фейковое окружение
    fastfetch               # Вывод информации о системе и железе
    xclip                   # Работа с буфером обмена используя терминал
    xdotool                 # Зависимость для скрипта ~/bin/cursor_tracker.sh ?
    slop                    # Получить координаты клика мыши
    i3lock-color            # Для блокировки экрана

    # Дополнительные системные пакеты
    mat2                    # Очистка метаданных изображения
    noto-fonts-emoji-blob-bin   # Для отображения emoji в rofi
    noto-fonts-cjk-sans         # Для отображения emoji в rofi
    noto-fonts-cjk-serif        # Для отображения emoji в rofi
  ];
}
