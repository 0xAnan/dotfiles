#!/bin/bash
# Theme switcher using matugen
# Usage: theme-switch <path-to-wallpaper> [scheme-type]
# Example: theme-switch ~/Pictures/wallpaper.jpg
# Example: theme-switch ~/Pictures/wallpaper.jpg scheme-expressive

WALLPAPER="$1"
SCHEME_TYPE="${2:-scheme-tonal-spot}"

if [ -z "$WALLPAPER" ]; then
    echo "Usage: theme-switch <wallpaper-path> [scheme-type]"
    echo ""
    echo "Scheme types:"
    echo "  scheme-tonal-spot   (default, balanced)"
    echo "  scheme-vibrant      (more colorful)"
    echo "  scheme-expressive   (bold and artistic)"
    echo "  scheme-fidelity     (closest to source)"
    echo "  scheme-content      (content-based)"
    echo "  scheme-neutral      (muted)"
    echo "  scheme-monochrome   (grayscale)"
    echo "  scheme-fruit-salad  (playful)"
    echo "  scheme-rainbow      (rainbow)"
    exit 1
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Error: File not found: $WALLPAPER"
    exit 1
fi

# Generate theme
echo "Generating theme from: $WALLPAPER ($SCHEME_TYPE)"
matugen image "$WALLPAPER" -t "$SCHEME_TYPE"

# Set wallpaper with swww
if command -v swww &>/dev/null; then
    swww img "$WALLPAPER" --transition-type grow --transition-duration 1.5
fi

# Reload hyprland
hyprctl reload 2>/dev/null

echo "Done! Theme applied."
