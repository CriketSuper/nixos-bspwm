# Установка и откат

## Быстрый путь

1. Установите NixOS на новый ПК штатным установщиком, выберите UEFI и создайте обычного пользователя с паролем.
2. Скачайте репозиторий и запустите `scripts/install.sh` с нужным профилем и именем этого пользователя.
3. Сначала используйте `--mode build`; проверьте `local/hardware-configuration.nix` и `local/settings.nix`.
4. Выполните `sudo nixos-rebuild switch --flake path:/etc/nixos#current` и перезагрузитесь для нового экрана входа.

При запуске из `nix-shell -p git python3` передавайте его PATH через `sudo env PATH="$PATH"`.
Для автоматической установки профиль надо указать явно. Без терминала выбирается `universal`.
Установщик не содержит операции с разделами и не назначает пароли.

## Ручная установка / BIOS / особые драйверы

Скопируйте репозиторий в `/etc/nixos/bspwm-repo` и создайте `/etc/nixos/local`.
Получите аппаратный конфиг **нового компьютера**, не исходного ноутбука:

```sh
sudo nixos-generate-config --show-hardware-config \
  | sudo tee /etc/nixos/local/hardware-configuration.nix >/dev/null
sudo cp /etc/nixos/bspwm-repo/examples/settings.nix /etc/nixos/local/settings.nix
sudo cp /etc/nixos/bspwm-repo/examples/private.nix /etc/nixos/local/private.nix
```

Отредактируйте имя, UID (`id -u`), домашнюю папку и исходный `stateVersion` установленной системы.
Локальный `/etc/nixos/flake.nix`:

```nix
{
  inputs.bspwm.url = "path:/etc/nixos/bspwm-repo";
  outputs = { bspwm, ... }: {
    nixosConfigurations.current = bspwm.lib.mkSystem {
      profile = "universal";
      modules = [ ./local/hardware-configuration.nix ./local/settings.nix ./local/private.nix ];
    };
  };
}
```

Для BIOS сохраните прежний работавший загрузчик в `private.nix`, отключив заданный по умолчанию systemd-boot через `lib.mkForce false`. Укажите корректное устройство GRUB самостоятельно.
Для NVIDIA добавьте соответствующие вашему GPU параметры драйвера в локальный модуль. Аппаратный сканер не выбирает проприетарный драйвер вместо вас.
В случае шифрования/LVM/RAID убедитесь, что `hardware-configuration.nix` и локальный модуль включают настройки прежней загрузки.
Сложные конфигурации с сетевыми томами, ZFS и дополнительными службами переносите вручную, сохраняя их прежние модули.

```sh
sudo nix --extra-experimental-features 'nix-command flakes' flake lock path:/etc/nixos
sudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild build --flake path:/etc/nixos#current
# После проверки:
sudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake path:/etc/nixos#current
```

## Локальные настройки

`local/settings.nix`: пользователь, hostname, UID, timezone, stateVersion, включение SSH, группы программ.
`local/private.nix`: дополнительные службы, гостевой SSH-пользователь, ссылки на необязательные RPM.
Секреты VPN храните в пользовательских данных клиента, WireGuard-ключ — отдельным файлом с правами root. Не вставляйте секретные значения в Nix-код: вычисленные конфиги/пакеты попадают в Nix store.
Домашние данные не восстанавливаются из этой конфигурации. Obsidian vault, Seafile, браузерные/почтовые данные переносите отдельно.
Параметры экранов сохраняются через Super+Ctrl+P на каждом ПК; EDID-профили старого ноутбука не публикуются.

Для существующего локального развёртывания `install.sh --replace` обновляет копию репозитория, сохраняя `local/`. Новые `--user`/`--ssh-key` в этом режиме не переписывают уже существующий `settings.nix`: отредактируйте его вручную.

## Откат

Без перезагрузки:

```sh
sudo nixos-rebuild switch --rollback
```

Если система не загружается, выберите предыдущее поколение в меню systemd-boot. Хранятся два поколения.
Установщик сохраняет текущую конфигурацию в `/var/backups/nixos-bspwm/<дата>/config-before.tar.gz` и путь старой системы в `system-path.txt`.
Из терминала можно вручную вызвать `<путь-из-system-path.txt>/bin/switch-to-configuration switch` с sudo.
Это возвращает активную систему. Для дальнейших сборок восстановите старые конфиги из архива; текущую папку `/etc/nixos` сначала переименуйте или отдельно сохраните.
После переноса проверьте звук, Wi-Fi/Ethernet, блокировку, GPU и внешние экраны.

## Публикация своего репозитория

В подготовленной папке уже есть Git-коммит. Создайте **пустой** репозиторий на выбранном Git-сервере:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/nixos-bspwm.git
git push -u origin main
git push origin --tags
```

Обновите адрес в README и примерах после создания remote.
Публикуйте `nixos-bspwm/`, а не всю рабочую папку с диагностикой, снимками окон и RPM.
