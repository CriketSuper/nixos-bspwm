{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        monitor = 0;
        follow = "mouse";
        shrink = "no";
        padding = 20;
        horizontal_padding = 20;

        offset = "(16, 60)";
        origin = "top-right";

        frame_width = 2;
        separator_height = 2;
        frame_color = "#161320";
        separator_color = "#161320";

        sort = "no";
        font = "JetBrainsMono Nerd Font 15";
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        show_age_threshold = 60;
        word_wrap = "yes";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;

        icon_position = "left";
        max_icon_size = 60;
        sticky_history = false;
        history_length = 6;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 0;

        mouse_left_click = "close_current";
        mouse_middle_click = "do_action";
        mouse_right_click = "close_all";
      };

      urgency_low = {
        background = "#1E1E2E";
        frame_color = "#989CFA";
        foreground = "#D9E0EE";
        timeout = 5;
      };

      urgency_normal = {
        background = "#1E1E2E";
        frame_color = "#989CFA";
        foreground = "#D9E0EE";
        timeout = 5;
      };

      urgency_critical = {
        background = "#1E1E2E";
        frame_color = "#989CFA";
        foreground = "#D9E0EE";
        timeout = 10;
      };
    };
  };
}
