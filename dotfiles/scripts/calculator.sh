#!/usr/bin/env sh

exec rofi -show calc -modi calc -no-show-match -no-sort \
  -calc-command "printf '%s' '{result}' | xclip -selection clipboard"
