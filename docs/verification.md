# Проверка конфигурации

## Сборка профилей

```sh
nix --extra-experimental-features 'nix-command flakes' flake check
```

Проверка собирает оба профиля: `universal` и `huawei-matebook-d16`.
Их тестовые файловые системы предназначены для проверки сборки. Для установки используются разделы и оборудование целевого ПК, полученные через `nixos-generate-config`.

## Переносимость параметров

```sh
nix --extra-experimental-features 'nix-command flakes' eval --impure --json \
  --expr 'import ./tests/profile-portability.nix { repo = builtins.getFlake (toString ./.); }'
```

Проверяются пользователь и UID, пути Home Manager и Hiddify, права доступа к RDP, разделение аппаратных настроек Huawei и универсального профиля.

## Установщик и скрипты

```sh
shellcheck install.sh scripts/install.sh scripts/install-wizard.sh scripts/update.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

Проверки генератора настроек охватывают выбор компонентов, значения портов, обработку некорректных параметров и экранирование строк Nix.

## Оборудование

Huawei-профиль рассчитан на MateBook D16 AMD BOM-WXX9. Универсальный профиль поддерживает x86_64 Intel/AMD; дополнительные драйверы задаются локальным модулем.
После установки проверьте звук, Wi-Fi/Ethernet, блокировку, GPU и внешние экраны на целевом ПК.
