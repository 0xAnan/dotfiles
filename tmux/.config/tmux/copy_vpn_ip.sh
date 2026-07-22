#!/usr/bin/env bash

ip_addr="$("$HOME/.config/tmux/vpn_ip.sh")"

if [[ -z "$ip_addr" ]]; then
	tmux display-message "VPN IP not available"
	exit 0
fi

tmux set-buffer -w -- "$ip_addr"

if command -v wl-copy >/dev/null 2>&1; then
	printf '%s' "$ip_addr" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
	printf '%s' "$ip_addr" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
	printf '%s' "$ip_addr" | xsel --clipboard --input
fi

tmux display-message "Copied VPN IP: $ip_addr"
