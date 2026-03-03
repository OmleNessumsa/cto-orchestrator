#!/bin/bash
# Rick Terminal Shell Integration for Bash
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
    printf '\e]7;file://%s%s\a' "${HOSTNAME}" "${PWD}"
}

# Track the last exit code
__rick_last_exit_code=0

# Track if we're in a command
__rick_in_command=0

# Debug trap - called before each command
__rick_debug_trap() {
    # Skip if this is part of PROMPT_COMMAND
    [[ "$BASH_COMMAND" == "$PROMPT_COMMAND" ]] && return

    # Mark command output start (only once per command)
    if [[ "$__rick_in_command" -eq 0 ]]; then
        __rick_in_command=1
        __rick_osc133_start "C"
    fi
}

# PROMPT_COMMAND - called before each prompt
__rick_prompt_command() {
    # Capture exit code first
    __rick_last_exit_code=$?

    # If we were in a command, report its exit code
    if [[ "$__rick_in_command" -eq 1 ]]; then
        __rick_osc133_start_param "D" "$__rick_last_exit_code"
        __rick_in_command=0
    fi

    # Mark prompt start
    __rick_osc133_start "A"

    # Report current directory
    __rick_report_cwd
}

# Set up the hooks
# Preserve existing PROMPT_COMMAND
if [[ -n "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="__rick_prompt_command; $PROMPT_COMMAND"
else
    PROMPT_COMMAND="__rick_prompt_command"
fi

# Set up DEBUG trap for command detection
trap '__rick_debug_trap' DEBUG

# Modify PS1 to include OSC 133;B marker
# This marks the end of prompt, start of command input
__rick_original_ps1="${PS1:-}"
PS1='\[\e]133;B\a\]'"${__rick_original_ps1}"

# Report initial directory
__rick_report_cwd

# Initial prompt start
__rick_osc133_start "A"
