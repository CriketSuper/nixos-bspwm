{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

  # Алиасы
    shellAliases = {
      cls = "clear";
      g = "git";
      n = "nvim";
      m = "micro";
      cat = "bat";
      feh = "feh --scale-down";

      # Системные логи
      syslog_emerg = "sudo dmesg --level=emerg,alert,crit";
      syslog = "sudo dmesg --level=err,warn";
      xlog = "grep \"(EE)\\|(WW)\\|error\\|failed\" ~/.local/share/xorg/Xorg.0.log";

      # Управление журналом systemd
      vacuum = "journalctl --vacuum-size=100M";
      vacuum_time = "journalctl --vacuum-time=2weeks";
    };

  # Универсальные переменные
  shellInit = ''
    # Отключаем приветствие
    set -U fish_greeting

    # Устанавливаем все универсальные переменные из вашего fish_variables
    set -U SXHKD_SHELL "sh"
    set -U fish_color_autosuggestion "555 brblack"
    set -U fish_color_cancel "-r"
    set -U fish_color_command "green"
    set -U fish_color_comment "red"
    set -U fish_color_cwd "green"
    set -U fish_color_cwd_root "red"
    set -U fish_color_end "green"
    set -U fish_color_error "brred"
    set -U fish_color_escape "brcyan"
    set -U fish_color_history_current "--bold"
    set -U fish_color_host "normal"
    set -U fish_color_host_remote "yellow"
    set -U fish_color_normal "normal"
    set -U fish_color_operator "brcyan"
    set -U fish_color_param "cyan"
    set -U fish_color_quote "yellow"
    set -U fish_color_redirection "cyan --bold"
    set -U fish_color_search_match "--background=111"
    set -U fish_color_selection "white --bold --background=brblack"
    set -U fish_color_status "red"
    set -U fish_color_user "brgreen"
    set -U fish_color_valid_path "--underline"
    set -U fish_key_bindings "fish_default_key_bindings"
    set -U fish_pager_color_completion "normal"
    set -U fish_pager_color_description "B3A06D yellow -i"
    set -U fish_pager_color_prefix "cyan --bold --underline"
    set -U fish_pager_color_progress "brwhite --background=cyan"
  '';

    # Код для интерактивных сессий
    interactiveShellInit = ''
      # Сюда можно добавлять команды из блока 'if status is-interactive'
    '';
  };
}
