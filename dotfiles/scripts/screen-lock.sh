#!/usr/bin/env sh
set -eu
umask 077

# Serialize all entry points (shortcut, power menu and suspend).
exec 9>"${XDG_RUNTIME_DIR:-$HOME/.cache}/screen-lock.guard"
flock -n 9 || exit 0
pgrep -u "$(id -u)" -x xsecurelock >/dev/null && exit 0

pause_level=$(dunstctl get-pause-level)
case "$pause_level" in
  ''|*[!0-9]*) printf '%s\n' 'Cannot read notification pause level' >&2; exit 1 ;;
esac

session_id=$(loginctl show-user "$(id -un)" -p Display --value 2>/dev/null || true)
session_path=''
if [ -n "$session_id" ]; then
  session_path=$(busctl --system call org.freedesktop.login1 \
    /org/freedesktop/login1 org.freedesktop.login1.Manager \
    GetSession s "$session_id" 2>/dev/null | cut -d '"' -f 2 || true)
fi

set_locked_hint() {
  [ -n "$session_path" ] || return 0
  busctl --system call org.freedesktop.login1 "$session_path" \
    org.freedesktop.login1.Session SetLockedHint b "$1" >/dev/null 2>&1 || true
}

cleanup() {
  # Wait for the locker and its authentication helper before restoring popups.
  while pgrep -u "$(id -u)" -x xsecurelock >/dev/null; do
    sleep 0.1
  done
  set_locked_hint false
  dunstctl set-pause-level "$pause_level" >/dev/null 2>&1 || true
  pkill -CONT -u "$(id -u)" -x sxhkd 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

# The highest pause level also hides already displayed/critical notifications.
dunstctl set-pause-level 100
set_locked_hint true
pkill -STOP -u "$(id -u)" -x sxhkd 2>/dev/null || true

# XSecureLock draws above the compositor, including application-owned popups.
# Passwords always remain masked here; revealing is restricted to the login greeter.
export XSECURELOCK_PAM_SERVICE=xsecurelock
export XSECURELOCK_SAVER=saver_mpv
# Only the selected wallpaper is listed; never scan personal pictures/videos.
export XSECURELOCK_LIST_VIDEOS_COMMAND='printf "%s\n" "$HOME/Pictures/wallpapers/5521453.jpg"'
export XSECURELOCK_IMAGE_DURATION_SECONDS=86400
export XSECURELOCK_VIDEOS_FLAGS='--no-config --loop-file=inf --panscan=1 --brightness=-30 --osd-level=0'
export XSECURELOCK_SHOW_USERNAME=0
export XSECURELOCK_BACKGROUND_COLOR='#1e1e2e'
export XSECURELOCK_AUTH_BACKGROUND_COLOR='#181b26'
export XSECURELOCK_AUTH_FOREGROUND_COLOR='#cdd6f4'
export XSECURELOCK_AUTH_WARNING_COLOR='#f38ba8'
export XSECURELOCK_FONT='Noto Sans:size=14'
export CRIKET_LOCK_STYLE=1
export XSECURELOCK_SHOW_KEYBOARD_LAYOUT=1
export XSECURELOCK_SHOW_DATETIME=1
export XSECURELOCK_DATETIME_FORMAT='%H:%M  %d.%m.%Y'
export XSECURELOCK_SHOW_HOSTNAME=0
export XSECURELOCK_AUTH_SOUNDS=0
export XSECURELOCK_PASSWORD_PROMPT=asterisks
export XSECURELOCK_AUTH_TIMEOUT=60
export XSECURELOCK_BLANK_TIMEOUT=300
xsecurelock
