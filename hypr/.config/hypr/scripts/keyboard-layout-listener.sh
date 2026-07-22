#!/usr/bin/env bash
set -euo pipefail

socket="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

layout_label() {
  case "$1" in
    *Arabic*|*ara*)
      printf 'Ar'
      ;;
    *English*|*US*|*us*)
      printf 'En'
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

show_osd() {
  local keyboard_name="$1"
  local active_keymap="$2"
  local label

  label="$(layout_label "$active_keymap")"
  pkill -f "$HOME/.config/hypr/scripts/keyboard-layout-osd.py" 2>/dev/null || true
  "$HOME/.config/hypr/scripts/keyboard-layout-osd.py" "$label" "$keyboard_name" &
}

socat -U - UNIX-CONNECT:"$socket" | while IFS= read -r event; do
  case "$event" in
    activelayout'>>'*)
      payload="${event#activelayout>>}"
      keyboard_name="${payload%%,*}"
      active_keymap="${payload#*,}"

      case "$keyboard_name" in
        redragon-gaming-kb|redragon-2.4g-wireless-receiver)
          show_osd "$keyboard_name" "$active_keymap"
          ;;
      esac
      ;;
  esac
done
