#!/usr/bin/env bash

# Poll tmux panes for agent state.  Codex (and several similar TUIs) put a
# braille spinner in the pane title while a turn is running; a running -> idle
# transition in a background pane is therefore a reliable "finished" signal.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-alert"
alerts_file="$cache_dir/alerts"
states_file="$cache_dir/states"
mkdir -p "$cache_dir" || exit 0

tmp_alerts="$alerts_file.$$"
tmp_states="$states_file.$$"
: > "$tmp_alerts" || exit 0
: > "$tmp_states" || exit 0

agent_process_pattern='(^|/)(codex|claude|aider|gemini|opencode|cursor-agent|goose|amp|agy)([[:space:]]|$)'
agy_process_pattern='(^|/)agy([[:space:]]|$)'
prompt_pattern='approval required|permission required|requires approval|needs your permission|requesting permission|waiting for approval|do you want to allow|would you like to (run|allow|proceed)|allow .*[?]|approve .*[?]|proceed[?]|continue[?]|\[[Yy]/[Nn]\]|\([Yy]/[Nn]\)|yes/no|confirm .*[?]|press enter to (continue|confirm)'
# Codex and Claude animate their terminal title with this fixed-width Braille
# spinner while working.
spinner_pattern='^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] '

# Build the complete desired state in memory first.  Clearing each window and
# setting it again during the same poll makes a yellow pill visibly flash grey.
declare -A desired_window_alert=()
declare -A desired_window_running=()

while IFS='|' read -r pane pane_pid window label command title pane_active window_active; do
	[[ -n "$pane" ]] || continue

	old_state="$(awk -F '\t' -v pane="$pane" '$1 == pane { print $2; exit }' "$states_file" 2>/dev/null)"
	alert="$(tmux show-options -pqv -t "$pane" @agent_alert 2>/dev/null)"
	alert_line="$(tmux show-options -pqv -t "$pane" @agent_alert_line 2>/dev/null)"
	previous_alert="$alert"
	previous_alert_line="$alert_line"

	children="$(ps -o args= --ppid "$pane_pid" 2>/dev/null)"
	processes="$(printf '%s\n%s\n' "$command" "$children")"
	is_agent=0
	is_agy=0
	content=''
	# Some launchers leave the agent below the pane shell, while others exec it
	# in place (Claude commonly does the latter).  Check both representations.
	# A spinner by itself is not enough: ordinary TUIs can animate their title.
	if printf '%s\n' "$processes" | grep -Eiq "$agent_process_pattern"; then
		is_agent=1
	fi
	if printf '%s\n' "$processes" | grep -Eiq "$agy_process_pattern"; then
		is_agy=1
	fi

	state=gone
	if (( is_agent )); then
		if [[ "$title" =~ $spinner_pattern ]]; then
			state=running
			desired_window_running["$window"]=1
		elif (( is_agy )); then
			# agy keeps a static title.  Its input prompt is present only while it
			# is idle; while it is thinking or using tools the prompt disappears.
			content="$(tmux capture-pane -pJ -t "$pane" -S -12 2>/dev/null | tail -n 8)"
			if printf '%s\n' "$content" | grep -Eq '^[[:space:]]*>.*$'; then
				state=idle
			else
				state=running
				desired_window_running["$window"]=1
			fi
		else
			state=idle
		fi
	fi
	printf '%s\t%s\n' "$pane" "$state" >> "$tmp_states"

	# Looking at the pane acknowledges its previous alert.
	if [[ "$pane_active" == 1 && "$window_active" == 1 ]]; then
		alert=''
		alert_line=''
	else
		if [[ -z "$content" ]]; then
			content="$(tmux capture-pane -pJ -t "$pane" -S -25 2>/dev/null | tail -n 18)"
		fi
		prompt_line="$(printf '%s\n' "$content" | grep -Eai "$prompt_pattern" | tail -n 1 | tr -s '[:space:]' ' ' | cut -c1-90)"

		if (( is_agent )) && [[ -n "$prompt_line" ]]; then
			alert=action
			alert_line="$prompt_line"
		elif [[ "$old_state" == running && "$state" != running ]]; then
			alert=finished
			alert_line='Agent finished'
		elif [[ "$state" == running ]]; then
			# A new turn supersedes an old completion/action marker.
			alert=''
			alert_line=''
		fi
	fi

	# Avoid redraws when pane state did not actually change.
	if [[ "$alert" != "$previous_alert" ]]; then
		tmux set-option -pqt "$pane" @agent_alert "$alert"
	fi
	if [[ "$alert_line" != "$previous_alert_line" ]]; then
		tmux set-option -pqt "$pane" @agent_alert_line "$alert_line"
	fi

	if [[ -n "$alert" ]]; then
		printf '%s\t%s\t%s\t%s\n' "$pane" "$label" "$alert" "$alert_line" >> "$tmp_alerts"
		window_alert="${desired_window_alert[$window]:-}"
		if [[ "$alert" == action || "$window_alert" != action ]]; then
			desired_window_alert["$window"]="$alert"
		fi
	fi
done < <(tmux list-panes -a -F '#{pane_id}|#{pane_pid}|#{window_id}|#{session_name}:#{window_index}.#{pane_index}|#{pane_current_command}|#{pane_title}|#{pane_active}|#{window_active}' 2>/dev/null)

# Commit each final window state once, and only if its value changed.
while IFS= read -r window; do
	[[ -n "$window" ]] || continue
	desired_alert="${desired_window_alert[$window]:-}"
	desired_running="${desired_window_running[$window]:-0}"
	current_alert="$(tmux show-options -wqv -t "$window" @agent_alert 2>/dev/null)"
	current_running="$(tmux show-options -wqv -t "$window" @agent_running 2>/dev/null)"

	if [[ "$current_alert" != "$desired_alert" ]]; then
		tmux set-option -wqt "$window" @agent_alert "$desired_alert"
	fi
	if [[ "$current_running" != "$desired_running" ]]; then
		tmux set-option -wqt "$window" @agent_running "$desired_running"
	fi
done < <(tmux list-windows -a -F '#{window_id}' 2>/dev/null)

mv "$tmp_alerts" "$alerts_file"
mv "$tmp_states" "$states_file"

count="$(wc -l < "$alerts_file" 2>/dev/null | tr -d ' ')"
if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
	printf '#[range=user|agentalert]#[fg=#cba6f7,bg=default]#[fg=#11111b,bg=#cba6f7,bold] 󰚩 %s #[fg=#cba6f7,bg=default,nobold]#[norange] ' "$count"
fi
