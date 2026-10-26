# Полная установка NixOS и BSPWM на другой ПК

Эта инструкция рассчитана на **Intel/AMD x86_64, UEFI и профиль `universal`**.
Сначала устанавливается базовая NixOS 26.05, затем запускается английский мастер
из этого репозитория. Сам мастер BSPWM не размечает диски и не заменяет установщик ОС.

Вариант ниже использует весь выбранный внутренний диск: EFI 1 GiB, swap 16 GiB,
остальное ext4. Это установка без шифрования и без сохранения другой ОС.
**Разметка удалит все данные выбранного диска.** Для dual boot, LUKS, RAID или
Legacy BIOS нужна другая схема; не выполняйте этот раздел без изменений.

## 1. Сохранить данные и загрузиться с флешки

До переустановки перенесите нужные данные на другой носитель: домашние каталоги,
браузерные профили, SSH/GPG-ключи, VPN-настройки, документы и файлы приложений.
Репозиторий не содержит ваши личные данные и не восстанавливает их.

Запишите официальный **Minimal ISO, 64-bit Intel/AMD** со страницы
[NixOS Downloads](https://nixos.org/download/). Проверьте SHA-256 по файлу
контрольной суммы соответствующего выпуска. Если флешка уже записана и проверена,
повторять запись не нужно.

На целевом ПК выберите в Boot Menu пункт **UEFI: <имя флешки>**.
Для обычного официального образа отключите Secure Boot, если прошивка блокирует
загрузку. Эта инструкция не настраивает собственные ключи Secure Boot.

После загрузки в консоль:

```sh
sudo -i
export LC_ALL=C
loadkeys us
test -d /sys/firmware/efi && echo 'UEFI OK'
```

Если `UEFI OK` не появился, перезагрузитесь и выберите именно UEFI-загрузку.

## 2. Подключить интернет

С Ethernet обычно достаточно подключить кабель. Для Wi-Fi:

```sh
systemctl start NetworkManager
nmcli device wifi list
nmcli --ask device wifi connect 'YOUR_WIFI_NAME'
```

Введите пароль по запросу. Проверьте доступ:

```sh
curl -I https://nixos.org
```

## 3. Выбрать и разметить внутренний диск

```sh
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS
```

Определите **внутренний диск целевого ПК**, а не установочную USB-флешку.
Имена устройств на другом ПК могут отличаться. Ниже `/dev/nvme0n1` — пример;
для SATA-диска это может быть `/dev/sda`. Проверяйте модель и объём.

Следующий блок выполняйте в той же root-консоли. Он намеренно требует повторно
ввести полное имя диска перед стиранием:

```bash
disk=/dev/nvme0n1  # REPLACE with the target PC's internal disk
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS "$disk"
read -r -p "ALL DATA WILL BE ERASED. Type $disk to continue: " confirm
partitioned=false
if [ "$confirm" = "$disk" ]; then
  parted --script "$disk" -- \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart swap linux-swap 1025MiB 17409MiB \
    mkpart nixos ext4 17409MiB 100% && partitioned=true
  udevadm settle
else
  echo 'Cancelled. Do not continue to formatting.'
fi
```

Если отменили разметку или получили ошибку, **не переходите к форматированию**.
Для дисков NVMe/eMMC перед номером раздела нужна `p`, для SATA/USB — нет:

```bash
[ "$partitioned" = true ] || { echo 'Partitioning did not complete; stopping.'; exit 1; }
case "$disk" in *[0-9]) part="${disk}p" ;; *) part="$disk" ;; esac
lsblk "$disk"
```

Ещё раз убедитесь, что это нужный диск и новые разделы 1/2/3, затем:

```sh
mkfs.fat -F 32 -n EFI "${part}1"
mkswap -L swap "${part}2"
mkfs.ext4 -L nixos "${part}3"
mount "${part}3" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "${part}1" /mnt/boot
swapon "${part}2"
```

Swap 16 GiB здесь используется для обычной работы. Гибернация отдельно не настроена.

## 4. Установить базовую NixOS

Сгенерируйте аппаратный конфиг **на целевом ПК**:

```sh
nixos-generate-config --root /mnt
```

Создайте минимальный `configuration.nix`. В примере пользователь — `criket`,
имя компьютера — `nixos-pc`; при желании замените их **во всех последующих командах**.
Этот файл относится к новой установке, не копируйте его поверх рабочей системы.

```sh
cat > /mnt/etc/nixos/configuration.nix <<'EOF'
{ pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  users.users.criket = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  environment.systemPackages = with pkgs; [ git python3 dialog nano ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";
}
EOF
nixos-install
```

В конце `nixos-install` задайте пароль root. Затем обязательно назначьте пароль
обычному пользователю:

```sh
nixos-enter --root /mnt -c 'passwd criket'
umount -R /mnt
swapoff "${part}2"
reboot
```

Извлеките флешку при перезагрузке и загрузитесь с внутреннего диска.
Войдите как `criket`. На этом этапе графического рабочего стола ещё нет.

## 5. Установить BSPWM из репозитория

При необходимости снова подключите Wi-Fi через `nmcli --ask`:

```sh
nmcli --ask device wifi connect 'YOUR_WIFI_NAME'
git clone https://github.com/CriketSuper/nixos-bspwm.git
cd nixos-bspwm
./install.sh
```

Мастер запросит пароль sudo. Все его сообщения и кнопки английские, рамки ASCII.
На терминале нужен корректный `TERM`; для установки по SSH используйте `ssh -t`.

Выберите:

| Окно мастера | Значение |
| --- | --- |
| Hardware profile | **`universal`** для другого ПК |
| User account | `criket`, созданный при базовой установке |
| Computer name | Например `nixos-pc` |
| Time zone | `Asia/Yekaterinburg` или ваш пояс |
| Data compatibility | `26.05` для этой новой установки |
| Applications and services | Space отмечает компоненты; Enter продолжает |
| Review and install | **`build` — Build without activating** |

Development, Docker/QEMU, VPN и xrdp выбираются отдельно; обычные приложения и
основной рабочий стол устанавливаются всегда. SSH включайте, если он нужен;
мастер принимает публичный `.pub`-ключ. Закрытый ключ ему передавать не нужно.

Дождитесь **Build complete**. Если сборка завершилась ошибкой, не выполняйте switch;
журнал находится в `/var/log/nixos-bspwm/`.

Проверьте созданные настройки:

```sh
sudo cat /etc/nixos/local/settings.nix
sudo cat /etc/nixos/local/hardware-configuration.nix
```

Если нужны особые драйверы NVIDIA, нестандартный загрузчик или дополнительные
системные службы, внесите их в `/etc/nixos/local/private.nix` и повторите сборку.
Профиль `universal` сам не выбирает проприетарный драйвер NVIDIA; параметры зависят
от модели GPU и наличия гибридной графики. Используйте
[раздел NVIDIA в руководстве NixOS](https://nixos.org/manual/nixos/stable/#sec-x11-graphics-cards-nvidia).

При успешной сборке примените систему:

```sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake path:/etc/nixos#current
sudo reboot
```

На экране LightDM войдите своим пользователем и паролем, выбрав BSPWM, если нужен
выбор сеанса. Мастер сохраняет существующий пароль. Основная система репозитория
имеет русскую локаль; перевод мастера не меняет язык установленного рабочего стола.

## 6. После первого входа

Проверьте звук, микрофон, Wi-Fi, Bluetooth, блокировку и внешний монитор.
Настройте экраны через **Super+Ctrl+P**. Остальные сочетания перечислены в
[горячих клавишах](shortcuts.md). Верните личные данные и импортируйте VPN-подписки.
Необязательные сторонние RPM отсутствуют в Git; их настройка описана в
[основной инструкции](installation.md).

При неполадках войдите в консоль через Ctrl+Alt+F2. Последний журнал мастера:

```sh
sudo ls -t /var/log/nixos-bspwm/
```

## 7. Обновление и откат

Обновить копию репозитория и собрать систему:

```sh
sudo bash /etc/nixos/bspwm-repo/scripts/update.sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake path:/etc/nixos#current
```

Применяйте switch только после успешной сборки. Не повышайте `system.stateVersion`
при обычном обновлении. Локальные параметры хранятся в `/etc/nixos/local/`.

Откат активной системы:

```sh
sudo nixos-rebuild switch --rollback
```

Если система не загружается, выберите предыдущее поколение в systemd-boot.
Установщик сохраняет конфигурацию в `/var/backups/nixos-bspwm/`; восстановление
файлов и дополнительные способы отката описаны в [installation.md](installation.md).

Основа процедуры: [официальное руководство по установке NixOS](https://nixos.org/manual/nixos/stable/#sec-installation).
