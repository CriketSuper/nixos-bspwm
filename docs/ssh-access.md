# SSH: пароль, ключи и AllowUsers

Редактируйте **`/etc/nixos/configuration.nix`**. В нём уже есть один блок `services.openssh`; изменяйте его, не добавляя второй такой же блок.

Для входа обычного пользователя `criket` по паролю:

```nix
services.openssh = {
  enable = true;
  ports = [ 5555 ];
  openFirewall = true;
  settings = {
    PermitRootLogin = "no";
    AllowUsers = [ "criket" ];
    PasswordAuthentication = true;
    PubkeyAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
};
```

Замените имя, если пользователь называется иначе. Примените и проверьте:

```sh
sudo nixos-rebuild switch
sudo passwd criket  # Только если ещё не задан пароль этого пользователя
systemctl status sshd --no-pager
sudo sshd -T | rg 'passwordauthentication|pubkeyauthentication|allowusers|port '
```

С другого компьютера:

```sh
ssh -p 5555 criket@IP_КОМПЬЮТЕРА
```

`sshd` сам по себе ничего не печатает при штатном запуске службы. Состояние смотрят через `systemctl`, журнал — `sudo journalctl -u sshd -b --no-pager`. Сообщение `Permission denied (publickey)` после изменений требует проверить, успешно ли закончился switch, эффективный `sshd -T` и правильный ли IP/порт используются.

## Вход по ключу

В том же блоке поменяйте `PasswordAuthentication = false;` и `PubkeyAuthentication = true;`, затем отдельно в этом же главном файле добавьте:

```nix
users.users.criket.openssh.authorizedKeys.keys = [ "ssh-ed25519 YOUR_PUBLIC_KEY" ];
```

Используется только публичный ключ клиента. Закрытый ключ не копируется на сервер и не помещается в Nix-код. Секретные значения из Nix-конфигурации могут попасть в общедоступный Nix store, поэтому пароль задаётся через `passwd`.

## Дополнительный пользователь

В `configuration.nix` можно определить `users.users.sshuser.isNormalUser = true;`, не добавляя wheel. В существующем `AllowUsers` перечислите оба разрешённых имени: `[ "criket" "sshuser" ]`, примените систему и задайте новому пользователю пароль через `sudo passwd sshuser`.
