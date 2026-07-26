#!/usr/bin/env bash
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
        [[ -S "$socket" ]] || continue
        export WAYLAND_DISPLAY="${socket##*/}"
        break
    done
fi
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

pins_file="${XDG_DATA_HOME:-$HOME/.local/share}/cliphist-pins"
theme_file="$HOME/.config/hypr/rofi-cliphist.rasi"
history_limit="${CLIPHIST_ROFI_LIMIT:-150}"
mkdir -p "$(dirname "$pins_file")"

preview_text() {
    tr '\n\t\r' '   ' \
        | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/^(.{100}).+$/\1…/'
}

pin_text() {
    local text="$1" encoded tmp
    [[ -n "$text" ]] || exit 0

    encoded="$(printf '%s' "$text" | base64 -w 0)"
    touch "$pins_file"
    grep -Fxq "$encoded" "$pins_file" && exit 0

    tmp="$(mktemp)"
    {
        printf '%s\n' "$encoded"
        grep -Fxv "$encoded" "$pins_file" || true
    } > "$tmp"
    mv "$tmp" "$pins_file"
}

unpin_text() {
    local encoded="$1" tmp
    [[ -n "$encoded" && -f "$pins_file" ]] || exit 0

    tmp="$(mktemp)"
    grep -Fxv "$encoded" "$pins_file" > "$tmp" || true
    mv "$tmp" "$pins_file"
}

pin_display_to_encoded() {
    local selected="$1" wanted encoded decoded preview

    wanted="${selected#📌 }"
    [[ -n "$wanted" && -f "$pins_file" ]] || return 1

    while IFS= read -r encoded; do
        [[ -n "$encoded" ]] || continue
        decoded="$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)"
        [[ -n "$decoded" ]] || continue
        preview="$(printf '%s' "$decoded" | preview_text)"
        [[ "$preview" == "$wanted" ]] || continue
        printf '%s' "$encoded"
        return 0
    done < "$pins_file"

    return 1
}

decode_info() {
    local info="$1" kind payload

    kind="${info%%:*}"
    payload="${info#*:}"

    case "$kind" in
        pin)
            printf '%s' "$payload" | base64 -d
            ;;
        hist)
            printf '%s' "$payload" | cliphist decode
            ;;
    esac
}

selected_to_text() {
    local selected="$1" decoded

    decoded="$(printf '%s' "$selected" | cliphist decode 2>/dev/null || true)"
    if [[ -n "$decoded" ]]; then
        printf '%s' "$decoded"
    else
        printf '%s' "$selected"
    fi
}

print_row() {
    local display="$1" info="$2" meta="${3:-$1}"

    printf '%s\0display\x1f%s\x1finfo\x1f%s\x1fmeta\x1f%s\n' \
        "$display" "$display" "$info" "$meta"
}

print_menu() {
    local pinned_previews="" sep="" encoded decoded preview

    printf '\0prompt\x1f󰅇 clip\n'
    printf '\0message\x1fEnter copy  ·  Alt+Right pin  ·  Alt+Left unpin\n'
    printf '\0no-custom\x1ftrue\n'
    printf '\0use-hot-keys\x1ftrue\n'

    if [[ -s "$pins_file" ]]; then
        while IFS= read -r encoded; do
            [[ -n "$encoded" ]] || continue
            decoded="$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)"
            [[ -n "$decoded" ]] || continue
            preview="$(printf '%s' "$decoded" | preview_text)"
            pinned_previews="${pinned_previews}${sep}${preview}"
            sep=$'\034'
            printf '󰐃 %s\0display\x1f󰐃 %s\x1finfo\x1fpin:%s\x1fmeta\x1f%s pinned\x1factive\x1ftrue\n' \
                "$preview" "$preview" "$encoded" "$preview"
        done < "$pins_file"
        printf 'recent clipboard\0display\x1frecent clipboard\x1fnonselectable\x1ftrue\x1fpermanent\x1ftrue\n'
    fi

    cliphist list \
        | sed -n "1,${history_limit}p" \
        | awk -v pinned_previews="$pinned_previews" '
            BEGIN {
                split(pinned_previews, pinned, "\034")
                for (i in pinned) {
                    if (pinned[i] != "") {
                        is_pinned[pinned[i]] = 1
                    }
                }
            }
            /\[\[ binary data/ { next }
            {
                content = $0
                sub(/^[0-9]+\t/, "", content)
                content_preview = content
                gsub(/[[:space:]]+/, " ", content_preview)
                sub(/^ /, "", content_preview)
                sub(/ $/, "", content_preview)
                if (length(content_preview) > 100) {
                    content_preview = substr(content_preview, 1, 100) "…"
                }
                if (content_preview in is_pinned) {
                    next
                }

                display = $0
                gsub(/[[:space:]]+/, " ", display)
                sub(/^ /, "", display)
                sub(/ $/, "", display)
                if (length(display) > 100) {
                    display = substr(display, 1, 100) "…"
                }
                printf "%s%cdisplay%c%s%cinfo%chist:%s%cmeta%c%s\n", display, 0, 31, display, 31, 31, $0, 31, 31, display
            }
        '
}

if [[ "${1:-}" == "--rofi-script" ]]; then
    selected="${2:-}"

    case "${ROFI_RETV:-0}" in
        1)
            if [[ -n "${ROFI_INFO:-}" ]]; then
                decode_info "$ROFI_INFO" | wl-copy --type 'text/plain;charset=utf-8'
            elif [[ "$selected" == 📌* ]]; then
                encoded="$(pin_display_to_encoded "$selected" || true)"
                [[ -n "$encoded" ]] && printf '%s' "$encoded" | base64 -d | wl-copy --type 'text/plain;charset=utf-8'
            elif [[ -n "$selected" ]]; then
                selected_to_text "$selected" | wl-copy --type 'text/plain;charset=utf-8'
            fi
            exit 0
            ;;
        10)
            if [[ -n "${ROFI_INFO:-}" ]]; then
                pin_text "$(decode_info "$ROFI_INFO")"
            elif [[ "$selected" == 📌* ]]; then
                encoded="$(pin_display_to_encoded "$selected" || true)"
                [[ -n "$encoded" ]] && pin_text "$(printf '%s' "$encoded" | base64 -d)"
            elif [[ -n "$selected" ]]; then
                pin_text "$(selected_to_text "$selected")"
            fi
            print_menu
            exit 0
            ;;
        11)
            if [[ "${ROFI_INFO:-}" == pin:* ]]; then
                unpin_text "${ROFI_INFO#pin:}"
            elif [[ "$selected" == 📌* ]]; then
                encoded="$(pin_display_to_encoded "$selected" || true)"
                [[ -n "$encoded" ]] && unpin_text "$encoded"
            fi
            print_menu
            exit 0
            ;;
        *)
            print_menu
            exit 0
            ;;
    esac
fi

if ! command -v rofi >/dev/null 2>&1; then
    selection="$(cliphist list | tofi -c "$HOME/.config/tofi/configV")"
    [[ -n "$selection" ]] || exit 0
    printf '%s' "$selection" | cliphist decode | wl-copy --type 'text/plain;charset=utf-8'
    exit 0
fi

rofi \
    -show cliphist \
    -modes "cliphist:$0 --rofi-script" \
    -theme "$theme_file" \
    -matching fuzzy \
    -kb-custom-1 Alt+Right \
    -kb-custom-2 Alt+Left
