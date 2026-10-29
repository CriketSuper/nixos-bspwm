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

Flakes и экспериментальные возможности Nix не требуются. Home Manager подключён обычным системным модулем и применяется этой же командой. При установке один раз выбирается источник **NixOS 26.05**, и система сохраняет точный путь к нему в Nix store. Обычная правка SSH не обновляет ядро и все пакеты. Версия Home Manager закреплена в `sources.nix`.

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
sudo bash /var/lib/nixos-bspwm/source/scripts/activate.sh
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
sudo bash /var/lib/nixos-bspwm/source/scripts/activate.sh
```

Установщик сохранит существующую обычную конфигурацию и аппаратный конфиг. При переходе со старой flake-схемы он возьмёт аппаратный конфиг этого ПК и исходный `system.stateVersion`. Старые `flake.nix`, вложенный `bspwm-repo`, `local/`, ключи и `private.nix` останутся **только в локальной резервной копии** `/var/backups/nixos-bspwm/<дата>/config-before/`. В новую конфигурацию они не импортируются и на GitHub не отправляются. Выбор служб делается заново. Данные домашней папки не копируются.

Первый switch выполняется через `activate.sh`: он явно передаёт конфиг и тот же источник пакетов, который использовался при build. Прежний `NIX_PATH` может не содержать `nixos-config` или указывать на другой канал. После успешного переключения перезагрузитесь или заново войдите в сеанс. Дальше применяется обычный `sudo nixos-rebuild switch`.

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
└── docs/                     # Справка, доступная также в ~/nix-docs
```

В `/etc/nixos` нет Git-копии, тестов, установщика, примеров и ссылок `result`. Они хранятся отдельно в `/var/lib/nixos-bspwm/source`; резервные копии — в `/var/backups/nixos-bspwm`. `configuration.nix` и аппаратный конфиг относятся только к этому ПК и не публикуются. Чтобы выбрать второй профиль, замените **одну строку импорта** `./profiles/universal.nix` на `./profiles/huawei-matebook-d16.nix`. Для другого ПК аппаратный конфиг всегда должен быть его собственным.

SSH настраивается обычным блоком `services.openssh` в `configuration.nix`: [пароль, ключи и AllowUsers](docs/ssh-access.md). Пакеты добавляются там же в `environment.systemPackages` или в `packages/*.nix`. Изменения сразу читаются обычным `nixos-rebuild`; коммит, обновление Git и lock-файлы для применения не нужны.

## Приложения

Firefox, Chromium, Telegram, Thunderbird, Seafile, WindTerm, Obsidian, редакторы и остальные приложения берутся из Nixpkgs. **TG WS Proxy, ChatGPT desktop и LibreOffice 26.8** автоматически скачиваются с официальных серверов с проверкой SHA-256. RPM не надо переносить вручную, они не хранятся в Git. [Версии, источники и проверка пакетов](docs/rpm-packages.md).

Иконка Obsidian хранится локально: обращение к `obsidian.md` больше не является зависимостью сборки. Загрузка самого приложения из GitHub по-прежнему требует интернета.

VPN-подписки, пароли, токены, SSH/VPN-ключи, браузерные профили и данные приложений не включаются в репозиторий. Для входа в ChatGPT, почту и другие приложения авторизуйтесь отдельно на новом ПК.

## Обновление

Для своих изменений достаточно `sudo nixos-rebuild switch`.
Чтобы получить новые общие модули с GitHub и сначала проверить сборку:

```sh
sudo bash /var/lib/nixos-bspwm/source/scripts/update.sh
sudo nixos-rebuild switch
```

Скрипт сверяет общие файлы с установленной версией и остановится при локальных правках, чтобы их не перезаписать. Изменения в `configuration.nix` ему не мешают; этот файл сохраняется. Общий код обновляется отдельно от пакетов.

Обновить пакеты **намеренно** в пределах 26.05:

```sh
sudo nix-channel --update
sudo nixos-rebuild build -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos
# После успешной проверки:
sudo nixos-rebuild switch -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos
```

Именно эта операция может загрузить новые версии ядра и приложений. Для изменения SSH, hostname или списка служб она не нужна. При переходе на другой выпуск обновите совместимую версию Home Manager в `sources.nix`. Исходные `system.stateVersion` и `homeStateVersion` оставляйте прежними.

## Документация

- [Установка с нуля](docs/fresh-install.md), [миграция и откат](docs/installation.md)
- [SSH](docs/ssh-access.md), [xrdp](docs/rdp.md), [мониторы](docs/monitors.md)
- [Горячие клавиши](docs/shortcuts.md), [VPN](docs/vpn.md), [OpenVPN](docs/openvpn.md)
- [RPM-приложения](docs/rpm-packages.md), [проверки](docs/verification.md)

## Авторство

**[Zproger](https://github.com/Zproger)** — автор оригинального [bspwm-dotfiles](https://github.com/Zproger/bspwm-dotfiles) для Arch Linux. Перенос на NixOS, модули, установщик и изменения относятся к этому форку. Исходная MIT-лицензия и уведомление сохранены в [LICENSE](LICENSE). Внешние компоненты имеют собственные лицензии: [THIRD_PARTY.md](THIRD_PARTY.md).
