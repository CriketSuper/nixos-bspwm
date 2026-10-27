# NixOS BSPWM — обычная конфигурация в /etc/nixos

Рабочий стол и оформление исходного ноутбука с двумя аппаратными профилями:

| Профиль | Для чего |
| --- | --- |
| `universal` | Другой ПК с Intel/AMD x86_64 |
| `huawei-matebook-d16` | Huawei MateBook D16 AMD BOM-WXX9 |

Все файлы лежат прямо в `/etc/nixos`. Основные настройки меняются в `configuration.nix`, затем применяются командой:

```sh
sudo nixos-rebuild switch
```

Flakes и экспериментальные возможности Nix не требуются. Home Manager подключён обычным системным модулем и применяется этой же командой. Nixpkgs берётся из стандартного канала **NixOS 26.05**; версия Home Manager закреплена в `sources.nix`.

## Установка на готовую NixOS

На **целевом ПК** должны быть NixOS 26.05 x86_64/UEFI, интернет и обычный пользователь с паролем. Если ОС ещё нет, см. [полную установку с флешки](docs/fresh-install.md).

```sh
nix-shell -p git --run 'git clone https://github.com/CriketSuper/nixos-bspwm.git nixos-bspwm-classic'
cd nixos-bspwm-classic
./install.sh
```

Мастер работает на английском с ASCII-рамками. Выберите профиль, существующего пользователя, компоненты и способ входа по SSH. По умолчанию SSH выключен; режим **password** использует существующий пароль пользователя и отключает вход по ключу. Режим **key** требует самостоятельно добавить публичный ключ до активации.

Действие **build** сначала собирает систему без активации. После успешной сборки:

```sh
sudo nixos-rebuild switch
sudo reboot
```

Вариант без мастера (SSH остаётся выключен):

```sh
sudo env PATH="$PATH" bash scripts/install.sh \
  --profile universal --user criket --mode build
```

Пароль уже существующего пользователя остаётся на этом ПК. Установщик не назначает пароли и не переносит их с другого устройства.

## Переход со старой установки

Переустановка ОС не нужна, работающая графика сохраняется до успешного switch. Скачайте **новую копию** репозитория по команде выше, затем запустите мастер и подтвердите замену старого развёртывания. Профиль для другого ПК — `universal`.

Или из новой копии выполните (здесь SSH включён по паролю):

```sh
sudo env PATH="$PATH" bash scripts/install.sh --replace \
  --profile universal --user criket --ssh-mode password --mode build
sudo nixos-rebuild switch
```

Установщик возьмёт аппаратный конфиг этого ПК и исходный `system.stateVersion`. Старые `flake.nix`, вложенный `bspwm-repo`, `local/`, ключи и `private.nix` останутся **только в локальной резервной копии** `/var/backups/nixos-bspwm/<дата>/config-before/`. В новую конфигурацию они не импортируются и на GitHub не отправляются. Выбор служб делается заново. Данные домашней папки не копируются.

Если первоначальный `stateVersion` записан сложным выражением, укажите его через `--state-version YY.MM`; установщик не заменяет его номером текущего выпуска. Нестандартный загрузчик, NVIDIA и дополнительные службы из старых модулей перенесите вручную до switch: [подробности и откат](docs/installation.md).

## Где что редактировать

```text
/etc/nixos/
├── configuration.nix          # Пользователь, профиль, SSH, службы, дополнительные пакеты
├── hardware-configuration.nix # Разделы и оборудование ЭТОГО компьютера
├── profiles/                 # universal.nix и huawei-matebook-d16.nix
├── modules/                  # Общие настройки NixOS
├── packages/                 # Списки и рецепты приложений
├── services/                 # Звук, сеть, экраны, VPN, RDP
├── home.nix                  # Home Manager и настройки рабочего стола
├── dotfiles/                 # BSPWM, клавиши, Polybar, Rofi, оформление
├── sources.nix               # Версия системного модуля Home Manager
└── scripts/
```

`configuration.nix` и аппаратный конфиг исключены из Git. Чтобы выбрать второй профиль, замените **одну строку импорта** `./profiles/universal.nix` на `./profiles/huawei-matebook-d16.nix`. Для другого ПК аппаратный конфиг всегда должен быть его собственным.

SSH настраивается обычным блоком `services.openssh` в `configuration.nix`: [пароль, ключи и AllowUsers](docs/ssh-access.md). Пакеты добавляются там же в `environment.systemPackages` или в `packages/*.nix`. Изменения сразу читаются обычным `nixos-rebuild`; коммит, обновление Git и lock-файлы для применения не нужны.

## Приложения

Firefox, Chromium, Telegram, Thunderbird, Seafile, WindTerm, Obsidian, редакторы и остальные приложения берутся из Nixpkgs. **TG WS Proxy, ChatGPT desktop и LibreOffice 26.8** автоматически скачиваются с официальных серверов с проверкой SHA-256. RPM не надо переносить вручную, они не хранятся в Git. [Версии, источники и проверка пакетов](docs/rpm-packages.md).

Иконка Obsidian хранится локально: обращение к `obsidian.md` больше не является зависимостью сборки. Загрузка самого приложения из GitHub по-прежнему требует интернета.

VPN-подписки, пароли, токены, SSH/VPN-ключи, браузерные профили и данные приложений не включаются в репозиторий. Для входа в ChatGPT, почту и другие приложения авторизуйтесь отдельно на новом ПК.

## Обновление

Для своих изменений достаточно `sudo nixos-rebuild switch`.
Чтобы получить новые общие модули с GitHub и сначала проверить сборку:

```sh
sudo bash /etc/nixos/scripts/update.sh
sudo nixos-rebuild switch
```

Скрипт остановится при незакоммиченных изменениях общих файлов; локальный `configuration.nix` ему не мешает. Обновление стандартного канала в пределах 26.05: `sudo nix-channel --update`. При переходе на следующий выпуск обновляйте совместимую версию Home Manager в `sources.nix`. Исходные `system.stateVersion` и `homeStateVersion` при обычном обновлении оставляйте прежними.

## Документация

- [Установка с нуля](docs/fresh-install.md), [миграция и откат](docs/installation.md)
- [SSH](docs/ssh-access.md), [xrdp](docs/rdp.md), [мониторы](docs/monitors.md)
- [Горячие клавиши](docs/shortcuts.md), [VPN](docs/vpn.md), [OpenVPN](docs/openvpn.md)
- [RPM-приложения](docs/rpm-packages.md), [проверки](docs/verification.md)

## Авторство

**[Zproger](https://github.com/Zproger)** — автор оригинального [bspwm-dotfiles](https://github.com/Zproger/bspwm-dotfiles) для Arch Linux. Перенос на NixOS, модули, установщик и изменения относятся к этому форку. Исходная MIT-лицензия и уведомление сохранены в [LICENSE](LICENSE). Внешние компоненты имеют собственные лицензии: [THIRD_PARTY.md](THIRD_PARTY.md).
