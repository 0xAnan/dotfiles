#!/usr/bin/env bash

set -u

# Dynamic status commands and animated agent pane titles can make tmux repaint
# while a popup is visible, which produces a flickering/corrupted top border.
# Keep a static status-right for the popup lifetime, then restore everything.
old_interval="$(tmux show-options -gqv status-interval 2>/dev/null)"
old_status_right="$(tmux show-options -gqv status-right 2>/dev/null)"
static_status_right='#[fg=#89b4fa,bg=default]#[fg=#11111b,bg=#89b4fa,bold]鬼 #[fg=#cdd6f4,bg=#313244,nobold] #W #[fg=#313244,bg=default]'

cleanup() {
	tmux set-option -g status-right "$old_status_right" 2>/dev/null || true
	tmux set-option -g status-interval "${old_interval:-3}" 2>/dev/null || true
	tmux set-option -gu @popup_active 2>/dev/null || true
	tmux refresh-client -S 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

tmux set-option -gq @popup_active 1
tmux set-option -g status-interval 0
tmux set-option -g status-right "$static_status_right"
tmux refresh-client -S 2>/dev/null || true

"$@"
