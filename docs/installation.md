# Установка, миграция и откат

Нужна установленная NixOS 26.05 x86_64/UEFI с обычным пользователем и паролем. Для пустого диска см. [установку с нуля](fresh-install.md). Выполняйте команды **на целевом ПК**.

Скачайте новую копию репозитория, затем запустите английский мастер:

```sh
nix-shell -p git --run 'git clone https://github.com/CriketSuper/nixos-bspwm.git nixos-bspwm-classic'
cd nixos-bspwm-classic
./install.sh
```

Выберите `universal` для другого Intel/AMD ПК или `huawei-matebook-d16` для AMD BOM-WXX9. Мастер спросит пользователя, hostname, часовой пояс, первоначальный `stateVersion`, группы программ, RDP и SSH. Для входа по паролю выберите **password**. Пароли мастер не спрашивает, ключи автоматически не переносит.

**build** готовит `/etc/nixos` и собирает систему без активации; **prepare** только готовит файлы; **switch** ещё и активирует успешную сборку. Лог: `/var/log/nixos-bspwm/`.

После успешного build:

```sh
sudo nixos-rebuild switch
sudo reboot
```

## Переход с прежнего развёртывания

Мастер предлагает заменить старую структуру. В командном режиме из **новой чистой Git-копии**:

```sh
sudo env PATH="$PATH" bash scripts/install.sh --replace \
  --profile universal --user criket --ssh-mode password --mode build
```

Затем проверьте `/etc/nixos/configuration.nix`, `/etc/nixos/hardware-configuration.nix` и выполните обычный switch. Исходный `system.stateVersion` берётся из прежнего `local/settings.nix` или `configuration.nix` без вычисления старой конфигурации. Если автоматически определить его нельзя, нужен `--state-version YY.MM` с реальным первоначальным значением.

Старый `/etc/nixos` перемещается целиком в `/var/backups/nixos-bspwm/<дата>/config-before/`, доступный только root. Он нужен для локального отката. **Ни `private.nix`, ни ключи, ни старый `local/settings.nix` не подключаются к новой системе.** Из старых файлов используются только аппаратный конфиг этого ПК и номер совместимости. Имя, UID и домашняя папка берутся у существующего пользователя. Пароль остаётся в локальной базе учётных записей; копирования паролей между ПК нет.

Службы выбираются заново. SSH выключен по умолчанию, если не выбран `--ssh-mode password` или `key`. Если мигрируете по SSH, включите нужный способ входа до активации; в режиме key добавьте публичный ключ вручную в новый `configuration.nix`.

Прежние изменения общих модулей, настройки дополнительных дисков, особого загрузчика и драйверов проверьте по локальной резервной копии перед switch. Дополнительные точки монтирования из аппаратного конфига сохраняются. Модули с секретами автоматически не импортируются. Рабочий стол до успешной активации остаётся прежним.

## Ручная установка, BIOS и особые драйверы

Для BIOS установщик не применяется. Сохраните собственные `configuration.nix` и `hardware-configuration.nix`, скопируйте общие файлы репозитория прямо в `/etc/nixos` и добавьте в imports:

```nix
./modules
./profiles/universal.nix
```

Пример обычного главного файла: [examples/configuration.nix](../examples/configuration.nix). Для BIOS отключите systemd-boot и настройте GRUB на проверенное устройство. Для NVIDIA сохраните настройки драйверов вашего GPU. При LUKS/LVM/RAID/ZFS сохраните все необходимые параметры загрузки и файловых систем. Проверяйте их до перезагрузки.

Home Manager подключается общим модулем. Дальше работают `sudo nixos-rebuild build` и `sudo nixos-rebuild switch`. Экспериментальные возможности Nix не требуются.

## Откат

Откат активной системы:

```sh
sudo nixos-rebuild switch --rollback
```

Он не возвращает исходники. Если нужно также восстановить конфиги, определите нужный каталог резервной копии и сохраните новый конфиг перед возвратом:

```sh
sudo ls /var/backups/nixos-bspwm/
# Replace DATE-PID with the actual backup directory name:
sudo mv /etc/nixos /etc/nixos-after-migration
sudo cp -a /var/backups/nixos-bspwm/DATE-PID/config-before /etc/nixos
```

Если новый конфиг ещё не активировался, switch --rollback не нужен: текущая система уже прежняя. Если система не загружается, выберите предыдущее поколение в systemd-boot. Путь прежней системы сохранён в `system-path.txt`, а GC-root защищает её от очистки.
