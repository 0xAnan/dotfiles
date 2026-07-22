#!/usr/bin/env bash

reset=$'\033[0m'
bold=$'\033[1m'
dim=$'\033[2m'
mauve=$'\033[38;2;203;166;247m'
blue=$'\033[38;2;137;180;250m'
green=$'\033[38;2;166;227;161m'
yellow=$'\033[38;2;249;226;175m'
text=$'\033[38;2;205;214;244m'
muted=$'\033[38;2;108;112;134m'

line() {
    printf '%s%-18s%s %s%s%s\n' "$blue" "$1" "$muted" "$text" "$2" "$reset"
}

section() {
    printf '\n%s%s%s%s\n' "$bold" "$mauve" "$1" "$reset"
    printf '%s%s%s\n' "$muted" "────────────────────────────────────────" "$reset"
}

clear
printf '%s%s tmux cheatsheet %s\n' "$bold" "$mauve" "$reset"
printf '%sPrefix: %sC-a%s\n' "$muted" "$yellow" "$reset"

section "Sessions"
line "C-a s" "session picker"
line "C-a w" "window picker"
line "C-a :" "command prompt"
line ":new -s name" "create a named session"
line ":attach -t name" "attach to session"
line ":kill-session" "kill current session"

section "Windows"
line "C-a c" "new window"
line "C-a ," "rename window"
line "C-a n / p" "next / previous window"
line "C-a 0..9" "jump to window"
line "C-a &" "kill window"

section "Panes"
line "C-a \\" "vertical split"
line "C-a -" "horizontal split"
line "Alt-arrows" "move between panes"
line "C-a z" "zoom pane"
line "C-a x" "kill pane"
line "C-a h/j/k/l" "resize pane"

section "Copy Mode"
line "C-a [" "enter copy mode"
line "Space" "start selection"
line "Enter" "copy selection"
line "Mouse drag" "copy pane-local selection"
line "q" "quit copy mode"

section "Installed Plugins"
line "C-a O" "sessionx picker"
line "C-a C-s" "save session layout"
line "C-a C-r" "restore session layout"
line "C-a I" "install TPM plugins"
line "C-a U" "update TPM plugins"

printf '\n%sPress any key to close%s ' "$dim" "$reset"
IFS= read -rsn1 _
