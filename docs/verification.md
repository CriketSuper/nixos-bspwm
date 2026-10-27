# Проверки

Все команды запускаются из корня репозитория. Используется обычный Nixpkgs из канала NixOS 26.05.

```sh
shellcheck install.sh scripts/*.sh
python3 -m unittest discover -s tests -p 'test_*.py'
nix-instantiate --eval --strict --json --expr 'import ./tests/profile-portability.nix {}'
nix-instantiate --eval --strict --json --expr 'import ./tests/native-options.nix {}'
nix-build tests/systems.nix -A universal.system --no-out-link
nix-build tests/systems.nix -A huawei-matebook-d16.system --no-out-link
```

Тестовые файловые системы используются только для сборки. Не устанавливайте полученные системы на реальное оборудование: настоящий аппаратный конфиг генерируется на целевом ПК.

Проверки охватывают разделение аппаратных профилей, произвольный UID/Home Manager, права xrdp, стандартные переопределения SSH, сохранение версии совместимости, отсутствие переноса приватных файлов и генерацию обычного configuration.nix. Проверка миграции работает в отдельном временном каталоге, не меняя `/etc/nixos`.

После установки на реальном ПК проверьте звук, сеть, GPU, блокировку, мониторы и выбранный способ входа по SSH. Сборка не заменяет проверку оборудования.
