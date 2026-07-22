#!/usr/bin/env bash

set -u

kind="${1:-window}"
target="${2:-$(tmux show-options -gqv @rename_popup_target 2>/dev/null)}"

[[ -n "$target" ]] || exit 1

edit_name() {
	local label="$1"
	local current="$2"
	local name status

	# fzf behaves consistently inside a tmux popup, visibly preloads the old
	# value, and gives Escape a real cancel action.  --phony makes this an input
	# box rather than a list selector; --print-query returns exactly what was
	# typed even though there are no candidates.
	name="$(
		FZF_DEFAULT_OPTS= fzf \
			--phony \
			--print-query \
			--query="$current" \
			--prompt="$label › " \
			--header="Current: ${current:-<empty>}   •   Enter: save   •   Esc: cancel" \
			--header-first \
			--info=hidden \
			--layout=reverse \
			--border=none \
			--no-sort \
			--bind='esc:abort' \
			--color='bg:-1,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,hl:#89b4fa,prompt:#cba6f7,header:#6c7086,pointer:#f5c2e7,spinner:#f9e2af' \
			</dev/null
	)"
	status=$?

	# fzf returns 130 for Escape/Ctrl-C and may return 1 after accepting a query
	# with no list item; the latter is still a successful text submission.
	(( status == 130 )) && return 1
	[[ -n "$name" ]] || return 1
	printf '%s' "$name"
}

case "$kind" in
	window)
		current="$(tmux display-message -p -t "$target" '#W')" || exit 1
		name="$(edit_name 'Window name' "$current")" || exit 0
		tmux rename-window -t "$target" -- "$name"
		;;
	pane)
		current="$(tmux display-message -p -t "$target" '#T')" || exit 1
		name="$(edit_name 'Pane title' "$current")" || exit 0
		tmux select-pane -t "$target" -T "$name"
		;;
	*)
		exit 1
		;;
esac
