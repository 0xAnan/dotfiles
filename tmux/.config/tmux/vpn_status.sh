#!/usr/bin/env bash

ip_addr="$("$HOME/.config/tmux/vpn_ip.sh")"

[[ -n "$ip_addr" ]] || exit 0

printf '#[range=user|vpnip]#[fg=#a6e3a1,bg=default]#[fg=#11111b,bg=#a6e3a1,bold]󰖂 %s #[fg=#a6e3a1,bg=default,nobold]#[norange] ' "$ip_addr"
