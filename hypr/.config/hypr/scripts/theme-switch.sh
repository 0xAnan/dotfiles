#!/bin/bash
# Theme switcher using matugen + awww
# Usage: theme-switch <path-to-wallpaper> [scheme-type]

WALLPAPER="$1"
SCHEME_TYPE="${2:-scheme-tonal-spot}"

if [ -z "$WALLPAPER" ]; then
    echo "Usage: theme-switch <wallpaper-path> [scheme-type]"
    exit 1
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Error: File not found: $WALLPAPER"
    exit 1
fi

EXT="${WALLPAPER##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

# If it's a GIF/video, extract a 1-frame preview PNG for fast color extraction
MATUGEN_INPUT="$WALLPAPER"
if [ "$EXT_LOWER" = "gif" ] || [ "$EXT_LOWER" = "webm" ] || [ "$EXT_LOWER" = "mp4" ]; then
    PREVIEW_PNG="${WALLPAPER%.*}_preview.png"
    ffmpeg -y -i "$WALLPAPER" -vframes 1 "$PREVIEW_PNG" &>/dev/null
    if [ -f "$PREVIEW_PNG" ]; then
        MATUGEN_INPUT="$PREVIEW_PNG"
    fi
fi

# Generate theme automatically without interactive prompt
echo "Generating theme from: $MATUGEN_INPUT ($SCHEME_TYPE)"
matugen image "$MATUGEN_INPUT" -t "$SCHEME_TYPE" --source-color-index 0

# Set animated or static wallpaper with awww
if command -v awww &>/dev/null; then
    awww img "$WALLPAPER" --transition-type grow --transition-duration 1.5
elif command -v swww &>/dev/null; then
    swww img "$WALLPAPER" --transition-type grow --transition-duration 1.5
fi

# Reload hyprland
hyprctl reload 2>/dev/null

echo "Done! Theme applied."
