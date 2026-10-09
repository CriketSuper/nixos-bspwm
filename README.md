# BSPWM для NixOS

Перенос оформления [Zproger/bspwm-dotfiles](https://github.com/Zproger/bspwm-dotfiles) на NixOS 26.05 с Home Manager.
Одна ветка `main`, общая оболочка и два профиля оборудования.

| Профиль | Назначение |
| --- | --- |
| `huawei-matebook-d16` | Huawei MateBook D16 AMD, проверенная конфигурация BOM-WXX9: современное ядро, SOF, ES8316/ACP3x, Fn Lock, AMD-подсветка |
| `universal` | Другие x86_64 ПК Intel/AMD; стандартное ядро и PipeWire, автоопределение батареи и подсветки, без исправлений кодека Huawei |

Рабочие столы, Polybar, Rofi, блокировка и оформление входа, горячие клавиши, история буфера, обои, многомониторные схемы и основные приложения общие.
Nixpkgs закреплён на том же коммите, что на исходном ноутбуке; версии Nixpkgs/Home Manager и хеши находятся в `flake.lock`.

## Установка из Git на другой ПК

Сначала установите NixOS обычным способом, создайте своего пользователя и подключитесь к интернету.
Скрипт поддерживает **уже установленную NixOS на x86_64 с UEFI**. Он не форматирует диски и не переносит UUID разделов исходного ноутбука.
Для BIOS, ARM, NVIDIA и нестандартных файловых систем см. [ручную установку](docs/installation.md).

После публикации этого репозитория замените `YOUR_ACCOUNT/nixos-bspwm` на собственный адрес:

```sh
nix-shell -p git python3 --run 'git clone https://github.com/YOUR_ACCOUNT/nixos-bspwm.git'
cd nixos-bspwm
sudo env PATH="$PATH" bash scripts/install.sh --profile universal --user YOUR_USER --mode build
```

Для такого же AMD MateBook используйте `--profile huawei-matebook-d16`.
По умолчанию только сборка: экран входа, сеть и работающие приложения не переключаются.
Перед применением посмотрите `/etc/nixos/local/hardware-configuration.nix` и `/etc/nixos/local/settings.nix`, затем:

```sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake path:/etc/nixos#current
```

Чтобы собрать и применить сразу:

```sh
sudo env PATH="$PATH" bash scripts/install.sh --profile universal --user YOUR_USER --mode switch
```

Можно запускать уже скачанный скрипт и клонировать указанный репозиторий внутри него:

```sh
sudo env PATH="$PATH" bash scripts/install.sh \
  --repo https://github.com/YOUR_ACCOUNT/nixos-bspwm.git \
  --ref main --profile universal --user YOUR_USER --mode build
```

`--mode prepare` только готовит конфиги и lock-файл.
`--ssh-key /path/to/key.pub` включает SSH на порту 5555 с публичным ключом; без этого SSH выключен.
Пароль существующего пользователя сохраняется. В репозитории нет `NOPASSWD` sudo.

## Что остаётся локальным

Установщик создаёт:

```text
/etc/nixos/
├── flake.nix                # Локальная сборка nixosConfigurations.current
├── flake.lock               # Зафиксированный исходник репозитория
├── bspwm-repo/              # Git-копия этого репозитория
└── local/
    ├── hardware-configuration.nix  # Разделы и оборудование конкретного ПК
    ├── settings.nix               # Пользователь, UID, hostname, stateVersion, SSH
    └── private.nix                # Локальные дополнения
```

Старый `configuration.nix` остаётся для справки, но после появления `flake.nix` сборка выполняется через flake.
Полная копия прежних конфигов сохраняется в `/var/backups/nixos-bspwm/`; прежняя система защищена GC-root.
Системный профиль сейчас использует `stateVersion = "26.05"`; Home Manager сохраняет отдельный `homeStateVersion = "25.05"`. Не повышайте эти значения при обычном обновлении без проверки изменения форматов данных. Скрипт сохраняет распознанное значение старого конфига; проверьте его перед применением, если старый конфиг был разбит на модули.

Публичные/закрытые SSH-ключи владельца, UUID его разделов, WireGuard-сервер, VPN-подписки, пароли, почтовые/браузерные профили и данные приложений сюда не копируются.
Владельцу текущего ноутбука не нужно запускать установщик поверх работающей системы, чтобы просто опубликовать репозиторий.

## Приложения

Основные пакеты берутся из закреплённого Nixpkgs: Firefox, Chromium, Thunderbird, Seafile, WindTerm, LibreOffice, Telegram, Obsidian, Codex CLI и прочие приложения исходного рабочего стола.
Hiddify 4.1.1 собирается из официального выпуска с SHA-256; v2rayA/Xray и AmneziaVPN — из Nixpkgs.
VPN-подписки добавляются вручную на новом ПК: готовая конфигурация клиента не содержит доступ к VPN.

Присланные RPM **ChatGPT desktop, TG WS Proxy и LibreOffice 26.8** не входят в Git.
Без RPM используется LibreOffice из Nixpkgs; ChatGPT desktop и TG WS Proxy не устанавливаются.
Их можно включить локально по образцу [examples/private.nix](examples/private.nix), скопировав сами пакеты отдельно в `/etc/nixos/local/vendor/`. Пути `./vendor/...` вычисляются относительно локального `private.nix`.
Codex CLI и ChatGPT desktop — разные приложения.

## Настройка и обновление

Оболочка: `dotfiles/`. Общие службы: `services/`. Пакеты: `packages/`. Аппаратные настройки: `profiles/`.
Параметры пользователя/функций: [modules/options.nix](modules/options.nix), пример: [examples/settings.nix](examples/settings.nix).
Отключение тяжёлых групп: `bspwmBuild.development.enable = false;`, `virtualisation.enable = false;`, `vpn.enable = false;` в локальном модуле.

Обновление из Git сначала собирает результат, затем его можно применить:

```sh
sudo bash /etc/nixos/bspwm-repo/scripts/update.sh
sudo nixos-rebuild switch --flake path:/etc/nixos#current
```

Пины зависимостей меняются отдельно и намеренно: отредактируйте коммиты inputs в `flake.nix`, выполните `nix flake update`, проверьте оба профиля и закоммитьте новый lock-файл.
Проверка параметризации: `nix eval --impure --json --expr 'import ./tests/profile-portability.nix { repo = builtins.getFlake (toString ./.); }'`.
Результаты `nix flake check` используют тестовые разделы с меткой `*-test-only`; их нельзя устанавливать как систему — установка всегда генерирует аппаратный конфиг этого ПК.

## Проверка

```sh
nix --extra-experimental-features 'nix-command flakes' flake check
shellcheck scripts/install.sh scripts/update.sh dotfiles/polybar/launch.sh
```

Проверены вычисление и сборка обоих профилей, параметризация пользователя, изолированная подготовка установки; сведения в [docs/verification.md](docs/verification.md).
Поддержку конкретного нового оборудования проверяйте после установки: универсальный профиль не означает, что все GPU и док-станции имеют одинаковые драйверы.

## Документация

- [Установка, сохранение настроек и откат](docs/installation.md)
- [Горячие клавиши](docs/shortcuts.md)
- [Дополнительные мониторы](docs/monitors.md)
- [VPN](docs/vpn.md), [TLS fingerprint](docs/vpn-fingerprints.md)
- [SSH и смена пароля](docs/ssh-access.md)
- [OpenVPN](docs/openvpn.md)
- [Дополнительный ChatGPT RPM](docs/chatgpt-update.md)
- [Происхождение компонентов](THIRD_PARTY.md)

Публикация выполняется владельцем; удалённый Git-сервер и remote пока не настроены.
