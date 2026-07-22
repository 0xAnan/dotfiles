#!/usr/bin/env bash

alerts_file="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-alert/alerts"

if [[ ! -s "$alerts_file" ]]; then
	tmux display-message "No agent alerts"
	exit 0
fi

IFS=$'\t' read -r pane label line < "$alerts_file"

if [[ -z "$pane" ]]; then
	tmux display-message "No agent alerts"
	exit 0
fi

session="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null || true)"
window="$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null || true)"

if [[ -n "$session" && -n "$window" ]]; then
	tmux switch-client -t "$session"
	tmux select-window -t "$window"
	tmux select-pane -t "$pane"
	tmux set-option -pqt "$pane" @agent_alert ''
	tmux set-option -pqt "$pane" @agent_alert_line ''
	tmux display-message "Agent alert: $label"
else
	tmux display-message "Agent alert pane is gone"
fi
