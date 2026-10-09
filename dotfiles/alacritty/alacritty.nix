{ config, pkgs, lib, ... }:

let
  theme = import ./themes.nix;
in
{
  programs.alacritty = {
    enable = true;
    settings = lib.recursiveUpdate theme {
      font = {
        builtin_box_drawing = true;
        size = 14.0;

        bold = {
          style = "Bold";
        };

        bold_italic = {
          style = "Bold Italic";
        };

        italic = {
          style = "Italic";
        };

        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
      };

      keyboard = {
        bindings = [
          {
            action = "Paste";
            key = "Y";
            mods = "Control";
          }
          {
            action = "Copy";
            key = "W";
            mods = "Alt";
          }
        ];
      };

      scrolling = {
        history = 100000;
        multiplier = 6;
      };

      selection = {
        save_to_clipboard = true;
        semantic_escape_chars = ",│`|:\"' ()[]{}<>\\t";
      };

      terminal = {
        shell = {
          program = "${pkgs.fish}/bin/fish";
        };
      };

      window = {
        dynamic_title = true;
        opacity = 1.0;
        title = "Alacritty";
        class = {
          general = "Alacritty";
          instance = "Alacritty";
        };
      };
    };
  };
}
