# RPM-приложения

Все три приложения устанавливаются по умолчанию. Ручной перенос RPM не нужен: Nix скачивает их по фиксированным официальным URL и проверяет SHA-256.

| Приложение | Версия | Источник |
| --- | --- | --- |
| TG WS Proxy | 1.10.4 | [Выпуск Flowseal](https://github.com/Flowseal/tg-ws-proxy/releases/tag/v1.10.4) |
| ChatGPT desktop | 26.1021.22027 | [Официальный RPM-репозиторий OpenAI](https://persistent.oaistatic.com/codex-app-prod/linux/rpm/x86_64/repodata/repomd.xml), [документация](https://learn.chatgpt.com/docs/linux/linux-app) |
| LibreOffice | 26.8.0.3 | [Архив Document Foundation](https://downloadarchive.documentfoundation.org/libreoffice/old/26.8.0.3/rpm/x86_64/) |

Рецепты: `packages/tg-ws-proxy.nix`, `packages/chatgpt-desktop.nix`, `packages/libreoffice-rpm.nix`. Контрольные суммы записаны в этих файлах. Для LibreOffice сверена официальная `.sha256`, для ChatGPT — метаданные RPM-репозитория, для TG WS Proxy — digest официального релиза.

RPM распаковываются при сборке; команды dnf/rpm для установки в систему и RPM-скрипты установки не запускаются. TG WS Proxy и ChatGPT используют autoPatchelf и обёртки с библиотеками Nix; LibreOffice запускается в FHS-окружении. LibreOffice 26.8 из RPM заменяет более старый LibreOffice канала 26.05.

ChatGPT для NixOS упакован этим проектом; NixOS отсутствует в официальном списке поддерживаемых дистрибутивов preview. Логин и данные ChatGPT не входят в RPM или репозиторий. После установки авторизуйтесь отдельно. Codex CLI из Nixpkgs — отдельная программа.

Если официальный сервер недоступен, сборка покажет ошибку загрузки. Версии не заменяются автоматически случайным latest или неофициальным зеркалом. Чтобы обновить RPM, измените URL/версию и SHA-256 рецепта, затем сначала выполните `sudo nixos-rebuild build`.

Можно явно задать уже скачанный официальный файл в `configuration.nix`:

```nix
bspwmBuild.vendor.chatgptSource = ./vendor/chatgpt-26.1021.22027-1.x86_64.rpm;
bspwmBuild.vendor.libreofficeSource = ./vendor/LibreOffice_26.8.0.3_Linux_x86-64_rpm.tar.gz;
bspwmBuild.vendor.tgWsProxySource = ./vendor/TgWsProxy_linux_amd64.rpm;
```

Эти строки необязательны. `vendor/` исключён из Git, установщик не переносит его со старого ПК. Не используйте эти параметры для файлов с секретами: исходные пакеты попадают в Nix store.

Hiddify использует официальный DEB и уже скачивается автоматически; это отдельный рецепт `packages/hiddify.nix`.
