# Дополнительный ChatGPT desktop

Codex CLI установлен из Nixpkgs. ChatGPT desktop из присланного RPM включается отдельно.
RPM не публикуется в репозитории. Скопируйте официальный установочный файл на новый ПК, в `/etc/nixos/local/vendor/`, и укажите в `/etc/nixos/local/private.nix`:

```nix
{ ... }: {
  bspwmBuild.vendor.chatgptSource = ./vendor/ChatGPT-26.1002.52244-x86_64.rpm;
}
```

Сборка и применение:

```sh
sudo nixos-rebuild build --flake path:/etc/nixos#current
sudo nixos-rebuild switch --flake path:/etc/nixos#current
```

Упаковка находится в `packages/chatgpt-desktop.nix`, рассчитана на протестированный RPM 26.1002.52244 для x86_64.
При обновлении получите новый официальный RPM, сохраните старый файл, обновите путь `chatgptSource` и версию рецепта, сначала выполните build. Новая версия может требовать изменения упаковки/зависимостей.
Прежний `chatgpt-update` для каналов исходного ноутбука не переносится в flake-репозиторий: он изменял другой путь и делал сборку через configuration.nix.
Обработчики обычных файлов и web-ссылок остаются у Thunar, Firefox и офисных приложений; ChatGPT сохраняет только codex deep link.
