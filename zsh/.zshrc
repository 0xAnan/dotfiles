# ~/.zshrc file for zsh interactive shells.
# see /usr/share/doc/zsh/examples/zshrc for examples

setopt autocd              # change directory just by typing its name
#setopt correct            # auto correct mistakes
setopt interactivecomments # allow comments in interactive mode
setopt magicequalsubst     # enable filename expansion for arguments of the form ‘anything=expression’
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

WORDCHARS=${WORDCHARS//\/} # Don't consider certain characters part of the word

# hide EOL sign ('%')
PROMPT_EOL_MARK=""

# configure key keybindings
bindkey -e                                        # emacs key bindings
bindkey ' ' magic-space                           # do history expansion on space
bindkey '^U' backward-kill-line                   # ctrl + U
bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[3~' delete-char                       # delete
bindkey '^[[1;5C' forward-word                    # ctrl + ->
bindkey '^[[1;5D' backward-word                   # ctrl + <-
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[H' beginning-of-line                  # home
bindkey '^[[F' end-of-line                        # end
bindkey '^[[Z' undo                               # shift + tab undo last action

copy-region-to-clipboard() {
    emulate -L zsh

    local start=$MARK end=$CURSOR tmp text

    if (( start == end )); then
        zle -M "No selected region"
        return 1
    fi

    if (( start > end )); then
        tmp=$start
        start=$end
        end=$tmp
    fi

    text="${BUFFER:$start:$(( end - start ))}"
    zle copy-region-as-kill

    if command -v wl-copy >/dev/null 2>&1; then
        print -rn -- "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        print -rn -- "$text" | xclip -selection clipboard
    else
        zle -M "Copied to zsh kill ring; no clipboard helper found"
        return 0
    fi

    zle -M "Copied selected text"
}
zle -N copy-region-to-clipboard
bindkey '^[w' copy-region-to-clipboard            # alt + w copies active region

# enable completion features
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

export KRB5_CONFIG=/etc/krb5.conf

tkt() {
    local ticket_path

    if [[ $# -ne 1 ]]; then
        echo "Usage: tkt <ccache file>"
        return 1
    fi

    if [[ "$1" = /* ]]; then
        ticket_path="$1"
    else
        ticket_path="$PWD/${1#./}"
    fi

    if [[ ! -f "$ticket_path" ]]; then
        echo "File not found: $ticket_path"
        return 1
    fi

    export KRB5CCNAME="$ticket_path"
    echo "KRB5CCNAME=$KRB5CCNAME"
}

compdef _files tkt

#compdef nxc
# Run something, muting output or redirecting it to the debug stream
# depending on the value of _ARC_DEBUG.
# If ARGCOMPLETE_USE_TEMPFILES is set, use tempfiles for IPC.
__python_argcomplete_run() {
    if [[ -z "${ARGCOMPLETE_USE_TEMPFILES-}" ]]; then
        __python_argcomplete_run_inner "$@"
        return
    fi
    local tmpfile="$(mktemp)"
    _ARGCOMPLETE_STDOUT_FILENAME="$tmpfile" __python_argcomplete_run_inner "$@"
    local code=$?
    cat "$tmpfile"
    rm "$tmpfile"
    return $code
}

__python_argcomplete_run_inner() {
    if [[ -z "${_ARC_DEBUG-}" ]]; then
        "$@" 8>&1 9>&2 1>/dev/null 2>&1 </dev/null
    else
        "$@" 8>&1 9>&2 1>&9 2>&1 </dev/null
    fi
}

_python_argcomplete() {
    local IFS=$'\013'
    local script=""
    if [[ -n "${ZSH_VERSION-}" ]]; then
        local completions
        completions=($(IFS="$IFS" \
            COMP_LINE="$BUFFER" \
            COMP_POINT="$CURSOR" \
            _ARGCOMPLETE=1 \
            _ARGCOMPLETE_SHELL="zsh" \
            _ARGCOMPLETE_SUPPRESS_SPACE=1 \
            __python_argcomplete_run ${script:-${words[1]}}))
        local nosort=()
        local nospace=()
        if is-at-least 5.8; then
            nosort=(-o nosort)
        fi
        if [[ "${completions-}" =~ ([^\\\\]): && "${match[1]}" =~ [=/:] ]]; then
            nospace=(-S '')
        fi
        _describe "${words[1]}" completions "${nosort[@]}" "${nospace[@]}"
    else
        local SUPPRESS_SPACE=0
        if compopt +o nospace 2> /dev/null; then
            SUPPRESS_SPACE=1
        fi
        COMPREPLY=($(IFS="$IFS" \
            COMP_LINE="$COMP_LINE" \
            COMP_POINT="$COMP_POINT" \
            COMP_TYPE="$COMP_TYPE" \
            _ARGCOMPLETE_COMP_WORDBREAKS="$COMP_WORDBREAKS" \
            _ARGCOMPLETE=1 \
            _ARGCOMPLETE_SHELL="bash" \
            _ARGCOMPLETE_SUPPRESS_SPACE=$SUPPRESS_SPACE \
            __python_argcomplete_run ${script:-$1}))
        if [[ $? != 0 ]]; then
            unset COMPREPLY
        elif [[ $SUPPRESS_SPACE == 1 ]] && [[ "${COMPREPLY-}" =~ [=/:]$ ]]; then
            compopt -o nospace
        fi
    fi
}
if [[ -z "${ZSH_VERSION-}" ]]; then
    complete -o nospace -o default -o bashdefault -F _python_argcomplete nxc
else
    # When called by the Zsh completion system, this will end with
    # "loadautofunc" when initially autoloaded and "shfunc" later on, otherwise,
    # the script was "eval"-ed so use "compdef" to register it with the
    # completion system
    autoload is-at-least
    if [[ $zsh_eval_context == *func ]]; then
        _python_argcomplete "$@"
    else
        compdef _python_argcomplete nxc
    fi
fi

# History configurations
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
#setopt share_history         # share command history data

# force zsh to show the complete history
alias history="history 0"

# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=no

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

configure_prompt() {
    prompt_symbol=㉿
    # Skull emoji for root terminal
    #[ "$EUID" -eq 0 ] && prompt_symbol=💀
    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
            # Right-side prompt with exit codes and background processes
            #RPROMPT=$'%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)'
            ;;
        oneline)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{%(#.red.blue)}%n@%m%b%F{reset}:%B%F{%(#.blue.green)}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
        backtrack)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{red}%n@%m%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
    esac
    unset prompt_symbol
}

# The following block is surrounded by two delimiters.
# These delimiters must not be modified. Thanks.
# START KALI CONFIG VARIABLES
PROMPT_ALTERNATIVE=twoline
NEWLINE_BEFORE_PROMPT=yes
# STOP KALI CONFIG VARIABLES

if [ "$color_prompt" = yes ]; then
    # override default virtualenv indicator in prompt
    VIRTUAL_ENV_DISABLE_PROMPT=1

    configure_prompt
    
else
    PROMPT='${debian_chroot:+($debian_chroot)}%n@%m:%~%(#.#.$) '
fi
unset color_prompt force_color_prompt

toggle_oneline_prompt(){
    if [ "$PROMPT_ALTERNATIVE" = oneline ]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi
    configure_prompt
    zle reset-prompt
}
zle -N toggle_oneline_prompt
bindkey ^P toggle_oneline_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%n@%m: %~\a'
    ;;
*)
    ;;
esac

precmd() {
    # Print the previously configured title
    print -Pnr -- "$TERM_TITLE"

    # Print a new line before the prompt, but only if it is not the first line
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}

_setEnv_tmux_sync() {
    [[ -z "$TMUX" ]] && return

    local generation_line generation keys_line envfile_line key line
    local -a keys

    generation_line="$(tmux show-environment -g SETENV_GENERATION 2>/dev/null)" || return
    generation="${generation_line#SETENV_GENERATION=}"

    [[ -z "$generation" || "$generation" == "$_SETENV_SYNC_GENERATION" ]] && return

    keys_line="$(tmux show-environment -g SETENV_KEYS 2>/dev/null)" || return
    keys=(${=keys_line#SETENV_KEYS=})

    for key in "${keys[@]}"; do
        line="$(tmux show-environment -g "$key" 2>/dev/null)" || continue

        if [[ "$line" == "-$key" ]]; then
            unset "$key"
            continue
        fi

        export "$line"
    done

    envfile_line="$(tmux show-environment -g SETENV_FILE 2>/dev/null)"
    if [[ "$envfile_line" == SETENV_FILE=* ]]; then
        export SETENV_FILE="${envfile_line#SETENV_FILE=}"
    fi

    export _SETENV_SYNC_GENERATION="$generation"
}

if [[ "${precmd_functions[(r)_setEnv_tmux_sync]}" != "_setEnv_tmux_sync" ]]; then
    precmd_functions+=(_setEnv_tmux_sync)
fi

# enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:" # fix ls color for folders with 777 permissions
	
	alias nc='ncat'
    alias vi='nvim'
    alias vim='nvim'
	alias cat='bat'
    alias cd='z'
	export BAT_THEME="Catppuccin Mocha"
    alias ls='exa --hyperlink'
    alias tree='exa --tree --hyperlink'
    alias fzf="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"
    alias quartzSync='cd ~/Documents/0xAnan-Blog && npx quartz sync --no-pull'
    alias clp='wl-copy <' 
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
    alias y='yazi'
    alias viz='vi ~/.zshrc'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

	alias date-on='sudo timedatectl set-ntp on'
	alias date-off='sudo timedatectl set-ntp off'

    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
    export LESS_TERMCAP_so=$'\E[01;33m'    # begin reverse video
    export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

    # Take advantage of $LS_COLORS for completion as well
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

# some more ls aliases
alias ll='exa -alh --hyperlink'
alias la='ls -A'
alias l='exa -F --hyperlink'
alias ILSpy='/home/anan/Arsenal/ILSpy/linux-x64/ILSpy'
#alias binja='/opt/binaryninja/binaryninja'
alias www='ls ~/www ; python3 -m http.server 80 -d ~/www'
alias pyweb='python3 -m http.server 80'
alias initScan='nmap -A -T5 -vv -oA enum/nmap/init'
alias bh-up='docker-compose -f ~/Arsenal/bloodhoundce/docker-compose.yml up -d;echo "URL: http://localhost:8989"'
alias bh-down='docker-compose -f ~/Arsenal/bloodhoundce/docker-compose.yml down'
alias waybar-restart='pkill waybar && waybar >/dev/null 2>&1 & disown'
alias payloads='penelope -a -i tun0 -p'

# enable auto-suggestions based on the history
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    # change suggestion color
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'
fi

# enable command-not-found if installed
if [ -f /etc/zsh_command_not_found ]; then
    . /etc/zsh_command_not_found
fi

###################### Chall Prep ############################

htb() {
    if [ -z "$1" ]; then
        echo "Usage: htb <MachineName>"
        return 1
    fi

    local HTB_DIR=~/HackTheBox/Machines
    local MACHINE_NAME="$1"
    local MACHINE_DIR="$HTB_DIR/$MACHINE_NAME"

    local DIRS=(
        config
        enum/nmap
        creds/
        tools/
        loot/bloodhound
        loot/dumps
        loot/files
        notes
        scratch
    )

    # Create base machine directory
    mkdir -p "$MACHINE_DIR"

    # Create subdirectories
    for dir in "${DIRS[@]}"; do
        mkdir -p "$MACHINE_DIR/$dir"
    done

    cd "$MACHINE_DIR" || return

    echo "HTB machine ready: $MACHINE_NAME"
    tree -L 3 "$MACHINE_DIR" 2>/dev/null || ls
}


web3() {
    if [ -z "$1" ]; then
        echo "Usage: web3 <ChallName>"
        return 1
    fi

    local WEB3_DIR=~/SmartContracts
    local CHALL_NAME="$1"
    local CHALL_DIR="$WEB3_DIR/$CHALL_NAME"

    if [ -d "$CHALL_DIR" ]; then
        echo "Changed Directory To: $CHALL_DIR"
    else
        mkdir -p "$CHALL_DIR"
        forge init "$CHALL_DIR"
        echo "Created: $CHALL_DIR and initialized foundry"
    fi

    cd "$CHALL_DIR" || return
}

setEnv() {
    local arg1="$1"
    local arg2="$2"
    local envfile=".env"
    local key value line generation
    local -a active_keys previous_keys managed_keys

    _setEnv_trim() {
        local value="$1"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        print -r -- "$value"
    }

    _setEnv_is_ipv4() {
        [[ "$1" =~ '^([0-9]{1,3}\.){3}[0-9]{1,3}$' ]]
    }

    _setEnv_upsert_file() {
        local envfile="$1"
        local key="$2"
        local value="$3"
        local tmpfile

        tmpfile="$(mktemp)" || return 1

        if [[ -f "$envfile" ]]; then
            awk -F= -v key="$key" -v value="$value" '
                BEGIN { updated = 0 }
                $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
                    if (!updated) {
                        print key "=" value
                        updated = 1
                    }
                    next
                }
                { print }
                END {
                    if (!updated) {
                        print key "=" value
                    }
                }
            ' "$envfile" > "$tmpfile" || {
                rm -f "$tmpfile"
                return 1
            }
        else
            printf '%s=%s\n' "$key" "$value" > "$tmpfile" || {
                rm -f "$tmpfile"
                return 1
            }
        fi

        mv "$tmpfile" "$envfile"
    }

    if [[ -z "$arg1" ]]; then
        envfile=".env"
    elif [[ -n "$arg2" ]]; then
        key="$arg1"
        value="$arg2"

        if [[ ! "$key" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]; then
            echo "Error: invalid variable name: $key"
            return 1
        fi

        _setEnv_upsert_file "$envfile" "$key" "$value" || return 1
        echo "Updated $envfile: $key=$value"
    elif [[ -f "$arg1" || "$arg1" == .env* || "$arg1" == */* ]]; then
        envfile="$arg1"
    elif _setEnv_is_ipv4 "$arg1"; then
        _setEnv_upsert_file "$envfile" "IP" "$arg1" || return 1
        echo "Updated $envfile: IP=$arg1"
    else
        echo "Usage: setEnv [envfile] | setEnv <ip> | setEnv <KEY> <VALUE>"
        return 1
    fi

    if [[ ! -f "$envfile" ]]; then
        echo "Error: $envfile not found"
        return 1
    fi

    if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
        line="$(tmux show-environment -g SETENV_KEYS 2>/dev/null)"
        if [[ "$line" == SETENV_KEYS=* ]]; then
            previous_keys=(${=line#SETENV_KEYS=})
        fi
    elif [[ -n "$SETENV_KEYS" ]]; then
        previous_keys=(${=SETENV_KEYS})
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line//[[:space:]]/}" || "$line" =~ '^[[:space:]]*#' ]] && continue

        IFS='=' read -r key value <<< "$line"
        key="$(_setEnv_trim "$key")"
        value="$(_setEnv_trim "$value")"

        [[ -z "$key" ]] && continue

        if [[ ! "$key" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]; then
            echo "Skipping invalid variable name in $envfile: $key"
            continue
        fi

        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        export "$key=$value"
        active_keys+=("$key")

        echo "Set: $key=$value"
    done < "$envfile"

    managed_keys=("${active_keys[@]}")
    for key in "${previous_keys[@]}"; do
        if (( ${managed_keys[(Ie)$key]} == 0 )); then
            managed_keys+=("$key")
        fi
        if (( ${active_keys[(Ie)$key]} == 0 )); then
            unset "$key"
        fi
    done

    export SETENV_KEYS="${(j: :)managed_keys}"
    export SETENV_FILE="${envfile:A}"

    if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
        for key in "${active_keys[@]}"; do
            tmux setenv -g "$key" "${(P)key}"
        done

        for key in "${previous_keys[@]}"; do
            if (( ${active_keys[(Ie)$key]} == 0 )); then
                tmux setenv -gr "$key"
            fi
        done

        tmux setenv -g SETENV_KEYS "$SETENV_KEYS"
        tmux setenv -g SETENV_FILE "$SETENV_FILE"

        generation="$(date +%s%N 2>/dev/null)"
        if [[ -z "$generation" || "$generation" == *N* ]]; then
            generation="$(date +%s)"
        fi

        tmux setenv -g SETENV_GENERATION "$generation"
        export _SETENV_SYNC_GENERATION="$generation"
    fi

    echo "Environment loaded from $envfile"
}



# Function to create CTF directory structure and move into it
ctf() {
    if [ -z "$1" ]; then
        echo "Please provide a CTF name."
        return 1
    fi

    # Base path for CTF directories
    CTF_DIR=~/CTFs/$1

    # Check if the CTF directory already exists
    if [ -d "$CTF_DIR" ]; then
        echo "Directory $CTF_DIR already exists."
        return 1
    fi

    # Create the base CTF directory
    mkdir -p "$CTF_DIR"

    # List of categories to create
    categories=("Web" "Blockchain" "Rev" "Pwn" "Crypto" "Misc" "OSINT" "Mobile" "Forensics" "Machines")

    # Create category directories inside the CTF directory
    for category in "${categories[@]}"; do
        mkdir -p "$CTF_DIR/$category"
    done

    # Inform the user
    echo "CTF directory structure for '$1' created successfully at $CTF_DIR"

    # Move to the newly created CTF directory
    cd "$CTF_DIR" || return 1
}


# Function to quickly move a file from ~/Downloads to the current directory
mvd() {
    # Ensure a file is specified
    if [ -z "$1" ]; then
        echo "Please specify a file to move."
        return 1
    fi

    # The file in ~/Downloads
    FILE=~/Downloads/$1

    # Check if the file exists
    if [ ! -f "$FILE" ]; then
        echo "File '$FILE' does not exist in ~/Downloads."
        return 1
    fi

    # Move the file to the current directory
    mv "$FILE" .

    # Inform the user
    echo "Moved '$FILE' to $(pwd)/"
}

# Enable tab completion for files in ~/Downloads for the mvd function
_mvd_files() {
    compadd $(ls ~/Downloads/)
}

# Bind completion for mvd to our custom function that lists files in ~/Downloads
compdef _mvd_files mvd


################# NetExec RID Bruteforce ########################


nxc_rid_brute() {
    usage() {
        echo "Usage:"
        echo "  nxc_rid_brute <target> <username> <password> <maxrid>"
        echo "  nxc_rid_brute <target> -k <maxrid>"
        return 1
    }

    if [[ $# -lt 2 ]]; then
        usage
        return 1
    fi

    local target="$1"
    shift

    local cmd
    local maxrid

    # Kerberos mode: -k <maxrid>
    if [[ "$1" == "-k" ]]; then
        if [[ $# -ne 2 ]]; then
            echo "Error: kerberos mode expects exactly 2 args after target: -k <maxrid>"
            usage
            return 1
        fi
        maxrid="$2"
        cmd=(nxc smb "$target" -k --use-kcache --rid-brute "$maxrid")
    else
        # Credential mode: <username> <password> <maxrid>
        if [[ $# -ne 3 ]]; then
            echo "Error: credential mode expects exactly 3 args after target: <username> <password> <maxrid>"
            usage
            return 1
        fi
        local username="$1"
        local password="$2"
        maxrid="$3"
        cmd=(nxc smb "$target" -u "$username" -p "$password" --rid-brute "$maxrid")
    fi

    # Run command and capture to a temporary file silently
    local tmpout
    tmpout=$(mktemp /tmp/nxc_rid_brute.XXXXXX) || tmpout="/tmp/nxc_rid_brute.$$"

    trap 'rm -f "$tmpout"' EXIT INT TERM

    "${cmd[@]}" > "$tmpout" 2>&1

    # Extract user-type SIDs (handles spaces too)
    grep '(SidTypeUser)' "$tmpout" | \
    awk 'match($0, /\\(.*) \(SidTypeUser\)/, a) { print a[1] }' | \
    sort -u | tee accounts.lst | \
    tee >(grep -E '\$$' > machines.lst) >(grep -vE '\$$' > users.lst) >/dev/null
        
    # Extract group-type SIDs (handles spaces in group names)
    grep '(SidTypeGroup)' "$tmpout" | \
    awk 'match($0, /\\(.*) \(SidTypeGroup\)/, a) { print a[1] }' | \
    sort -u > groups.lst


    # Summary counts
    local users_count machines_count groups_count total_count
    users_count=$(wc -l < users.lst 2>/dev/null || echo 0)
    machines_count=$(wc -l < machines.lst 2>/dev/null || echo 0)
    groups_count=$(wc -l < groups.lst 2>/dev/null || echo 0)
    total_count=$(wc -l < accounts.lst 2>/dev/null || echo 0)

    echo "Wrote: accounts.lst (users & machines), machines.lst (computer accounts), users.lst (human users), groups.lst (groups)"
    echo "Summary: $users_count users, $machines_count machines, $groups_count groups (total $total_count unique entries)"
}


###################### WORDLISTS #############################

export SECLISTS=~/Arsenal/Wordlists/seclists

# Directories
export DIRSMALL=$SECLISTS/Discovery/Web-Content/directory-list-2.3-small.txt
export DIRMEDIUM=$SECLISTS/Discovery/Web-Content/directory-list-2.3-medium.txt
export DIRBIG=$SECLISTS/Discovery/Web-Content/directory-list-2.3-big.txt
export WEBCOMMON=$SECLISTS/Discovery/Web-Content/common.txt
# API and Params
export WEBAPI_COMMON=$SECLISTS/Discovery/Web-Content/api/api-endpoints.txt
export WEBAPI_MAZEN=$SECLISTS/Discovery/Web-Content/common-api-endpoints-mazen160.txt
export WEBPARAM=$SECLISTS/Discovery/Web-Content/burp-parameter-names.txt
# DNS
export DNSSMALL=$SECLISTS/Discovery/DNS/subdomains-top1million-5000.txt
export DNSMEDIUM=$SECLISTS/Discovery/DNS/subdomains-top1million-20000.txt
export DNSBIG=$SECLISTS/Discovery/DNS/subdomains-top1million-110000.txt

# Passwords
export ROCKYOU=~/Arsenal/Wordlists/rockyou.txt
export XATO=$SECLISTS/Passwords/xato-net-10-million-passwords-1000000.txt

#################### Web3/Blockchain ################################
export UINT256_MAX=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
export DUMP_ADDRESS=0x1111111111111111111111111111111111111111


################### Other Configs ###############################
BLOODHOUND_PORT=8081


#################### Starship ###############################
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"


. "$HOME/.local/bin/env"

############





########## Android Studio ###############
# export ANDROID_SDK_ROOT=$HOME/Documents/Android/Sdk
# export PATH=$PATH:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools

export QT_QPA_PLATFORM=xcb
export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
#############################


eval $(thefuck --alias)

eval "$(zoxide init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion



# PATHES

export PATH="$HOME/.foundry/bin:$PATH"
export PATH="/home/anan/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

export ANDROID_SDK_ROOT="$HOME/Documents/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$PATH"
export ELECTRON_OZONE_PLATFORM_HINT=x11

export PATH=$PATH:/home/anan/.spicetify


# Hack The Box VPN helper
vpn() {
  local vpn_dir="${VPN_DIR:-$HOME/VPNs}"
  local name config

  if (( $# != 1 )); then
    print -u2 "Usage: vpn <vpn-name>"
    return 2
  fi

  name="$1"
  if [[ -f "$vpn_dir/$name" ]]; then
    config="$vpn_dir/$name"
  elif [[ -f "$vpn_dir/$name.ovpn" ]]; then
    config="$vpn_dir/$name.ovpn"
  else
    print -u2 "vpn: no config named $name in $vpn_dir"
    return 1
  fi

  sudo openvpn "$config"
}

_vpn() {
  local vpn_dir="${VPN_DIR:-$HOME/VPNs}"

  _files -W "$vpn_dir" -g '*.ovpn'
}
compdef _vpn vpn

# KeePass Google Drive helpers
export KP_LOCAL_DB="$HOME/Documents/KeePass/Passwords.kdbx"
export KP_REMOTE_DB="gdrive:KeePass/Passwords.kdbx"

kpush() {
  if [[ ! -f "$KP_LOCAL_DB" ]]; then
    print -u2 "kpush: local database not found: $KP_LOCAL_DB"
    return 1
  fi

  rclone copyto "$KP_LOCAL_DB" "$KP_REMOTE_DB" --progress
}

kpull() {
  rclone copyto "$KP_REMOTE_DB" "$KP_LOCAL_DB" --progress
}

# Load zsh-syntax-highlighting at the end so it can wrap final widgets correctly.
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
  # Catppuccin Mocha palette (256-color compatible)
  ZSH_HIGHLIGHT_STYLES[default]=none
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=211,bold,underline'
  ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=183,bold'
  ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=151,underline'
  ZSH_HIGHLIGHT_STYLES[global-alias]='fg=151,bold'
  ZSH_HIGHLIGHT_STYLES[precommand]='fg=117,underline'
  ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=111,bold'
  ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=111,underline'
  ZSH_HIGHLIGHT_STYLES[path]='fg=146,underline'
  ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=116'
  ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=60'
  ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=60'
  ZSH_HIGHLIGHT_STYLES[globbing]='fg=223,bold'
  ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=216,bold'
  ZSH_HIGHLIGHT_STYLES[command-substitution]='fg=146'
  ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=183,bold'
  ZSH_HIGHLIGHT_STYLES[process-substitution]='fg=146'
  ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=183,bold'
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=116'
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=116'
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=219'
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=183,bold'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=151'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=151'
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=151'
  ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=219'
  ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=219,bold'
  ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=219,bold'
  ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=219,bold'
  ZSH_HIGHLIGHT_STYLES[assign]='fg=216'
  ZSH_HIGHLIGHT_STYLES[redirection]='fg=111,bold'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=60,italic'
  ZSH_HIGHLIGHT_STYLES[named-fd]='fg=211'
  ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=211'
  ZSH_HIGHLIGHT_STYLES[arg0]='fg=117,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=211,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=111,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=151,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=223,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-level-4]='fg=216,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-level-5]='fg=183,bold'
  ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
fi
