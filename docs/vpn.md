# VPN

Репозиторий устанавливает клиенты; VPN-серверы, подписки, аккаунты и состояние подключения не переносятся.

- **v2rayA / Xray**: Super+Ctrl+A или `v2raya-ui`, интерфейс <http://127.0.0.1:2017>. Создайте аккаунт при первом открытии, импортируйте свою подписку, выберите узел и нажмите Start. Для системного подключения настройте transparent proxy в интерфейсе; состояние клиента хранится отдельно от Nix-кода в `/etc/v2raya`.
- **Hiddify 4.1.1**: Super+Shift+A или `hiddify`. Импортируйте свою подписку и выберите режим VPN для TUN. Режим системного прокси в BSPWM не используется.
- **AmneziaVPN**: открывается из меню; ключ/профиль добавляется отдельно.
- **OpenVPN**: импорт через NetworkManager, подробнее в [openvpn.md](openvpn.md).

Ярлыки Hiddify и v2rayA останавливают другую службу, чтобы два ядра не меняли маршруты одновременно.
Hiddify запускается по требованию от выбранного пользователя с `CAP_NET_ADMIN`/`CAP_NET_RAW`, не от root. Имя пользователя, домашняя папка и UID задаются в локальном модуле; X11-сессия LightDM использует дисплей :0.
v2rayA слушает только localhost; закрытие его вкладки не выключает подключение.
Перед запуском Amnezia выключите другой VPN.

```sh
systemctl status v2raya hiddify-gui AmneziaVPN
journalctl -u v2raya -b
journalctl -u hiddify-gui -b
sudo systemctl stop hiddify-gui
sudo systemctl start v2raya
```

Основной модуль: `/etc/nixos/bspwm-repo/services/vpn.nix`.
Hiddify закреплён по версии и SHA-256; v2rayA/Xray/Amnezia — по Nixpkgs lock-файлу.
TLS fingerprint: [инструкция](vpn-fingerprints.md).
Доступность конкретной подписки проверяется отдельно на новом ПК.
