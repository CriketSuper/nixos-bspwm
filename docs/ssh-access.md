# SSH и пароли

На новом ПК SSH выключен по умолчанию. В `local/settings.nix`:

```nix
bspwmBuild.ssh = {
  enable = true;
  port = 5555;
  authorizedKeys = [ "ssh-ed25519 YOUR_PUBLIC_KEY" ];
};
```

Пересоберите систему. `ssh -p 5555 youruser@IP` подключает владельца по ключу. Закрытый ключ остаётся на подключающемся компьютере.
Парольная аутентификация отключена; если нужна, отдельно установите `passwordAuthentication = true;`.

## Отдельный пользователь без sudo

Добавьте в `/etc/nixos/local/private.nix`:

```nix
{ ... }: {
  users.users.sshuser = {
    isNormalUser = true;
    homeMode = "0700";
    extraGroups = [];
    initialHashedPassword = "!";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 PUBLIC_KEY_OF_GUEST" ];
  };
  services.openssh.settings.AllowUsers = [ "youruser" "sshuser" ];
  services.displayManager.hiddenUsers = [ "sshuser" ];
}
```

Гость может использовать обычные команды, SSH/SFTP/SCP и складывать файлы в `/home/sshuser`, не имеет sudo. Системные общедоступные файлы остаются читаемыми; личная домашняя папка владельца получает режим `0700`.
После изменения: `sudo nixos-rebuild switch --flake path:/etc/nixos#current`.
Новые ключи добавляются только в локальный файл.

## Смена пароля

```sh
passwd                    # Свой пароль
sudo passwd youruser      # Пароль выбранного пользователя
```

Для sudo используется пароль пользователя, если отдельно не настроена другая политика.
