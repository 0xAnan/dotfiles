#!/usr/bin/env bash
set -euo pipefail

devices_json="$(hyprctl devices -j)"

keyboard_json="$(
  jq -c '
    def has_arabic_layout:
      (.layout // "") | split(",") | index("ara") != null;
    def real_keyboard:
      (.name | test("glorious|razer|power-button|sleep-button|consumer-control|system-control|mouse") | not);
    def redragon_keyboard:
      (.name | test("^redragon-(gaming-kb|2\\.4g-wireless-receiver)(-keyboard)?$"));

    (
      [.keyboards[] | select(redragon_keyboard and has_arabic_layout)][0]
      // [.keyboards[] | select(.main == true and real_keyboard and has_arabic_layout)][0]
      // [.keyboards[] | select(real_keyboard and has_arabic_layout)][0]
      // [.keyboards[] | select(has_arabic_layout)][0]
    )
  ' <<< "$devices_json"
)"

keyboard_name="$(jq -r '.name // empty' <<< "$keyboard_json")"
active_keymap="$(jq -r '.active_keymap // empty' <<< "$keyboard_json")"

case "$active_keymap" in
  *Arabic*|*ara*)
    label="Ar"
    class="arabic"
    ;;
  *English*|*US*|*us*)
    label="En"
    class="english"
    ;;
  "")
    label="--"
    class="unknown"
    active_keymap="Keyboard not found"
    keyboard_name="unknown"
    ;;
  *)
    label="$active_keymap"
    class="other"
    ;;
esac

jq -cn \
  --arg text "󰌌 $label" \
  --arg tooltip "$keyboard_name: $active_keymap" \
  --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
