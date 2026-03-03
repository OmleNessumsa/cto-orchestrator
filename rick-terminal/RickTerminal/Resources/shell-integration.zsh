#!/bin/zsh
# Rick Terminal Shell Integration for Zsh
# This script emits OSC 133 sequences for command boundary detection
# Similar to VS Code's terminal shell integration

# Only run if we're in Rick Terminal
[[ -z "$RICK_TERMINAL" ]] && return

# Mark that shell integration is active
export RICK_TERMINAL_SHELL_INTEGRATION=1

# OSC 133 sequence markers
__rick_osc133_start() {
    printf '\e]133;%s\a' "$1"
}

__rick_osc133_start_param() {
    printf '\e]133;%s;%s\a' "$1" "$2"
}

# Report current directory via OSC 7
__rick_report_cwd() {
    printf '\e]7;file://%s%s\a' "${HOST}" "${PWD}"
}

# Called before each prompt is displayed (PRECMD)
__rick_precmd() {
    local exit_code=$?

    # If we're completing a command, report its exit code
    if [[ -n "$__rick_command_started" ]]; then
        __rick_osc133_start_param "D" "$exit_code"
        unset __rick_command_started
    fi

    # Mark prompt start
    __rick_osc133_start "A"

    # Report current directory
    __rick_report_cwd
}

# Called after prompt is displayed, before command input
__rick_preexec() {
    # Mark that a command is about to start
    export __rick_command_started=1

    # Mark start of command output
    __rick_osc133_start "C"
}

# Custom widget to mark end of prompt/start of command input
__rick_line_init() {
    __rick_osc133_start "B"
}

# Set up the hooks
autoload -Uz add-zsh-hook

# Add our functions to the appropriate hooks
add-zsh-hook precmd __rick_precmd
add-zsh-hook preexec __rick_preexec

# Set up the line init widget (marks B after prompt)
# This fires when the user starts typing after the prompt
zle -N zle-line-init __rick_line_init 2>/dev/null || true

# Alternative approach: wrap the prompt itself
# This ensures B is emitted even without zle widget support
_rick_original_prompt="${PROMPT:-}"
PROMPT=$'%{\e]133;B\a%}'"${_rick_original_prompt}"

# Report initial directory
__rick_report_cwd

# Initial prompt start
__rick_osc133_start "A"
