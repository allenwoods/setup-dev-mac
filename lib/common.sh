#!/usr/bin/env bash
# common.sh - Shared utility functions for setup-dev-mac
# Provides logging, colors, and common utilities

set -euo pipefail

# ============================================================================
# Colors and Formatting
# ============================================================================

# Check if stdout is a terminal for color support
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly RESET='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly MAGENTA=''
    readonly CYAN=''
    readonly BOLD=''
    readonly DIM=''
    readonly RESET=''
fi

# ============================================================================
# Logging Functions
# ============================================================================

# Log levels: DEBUG, INFO, WARN, ERROR, SUCCESS
log_debug() {
    [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${DIM}[DEBUG]${RESET} $*" >&2
    return 0
}

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}==> $*${RESET}"
}

log_substep() {
    echo -e "  ${CYAN}->$RESET $*"
}

# ============================================================================
# User Interaction
# ============================================================================

# Ask yes/no question with default
# Usage: ask_yes_no "Question?" [default: y/n]
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local answer

    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        return 0
    fi

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -rp "$prompt" answer
    answer="${answer:-$default}"

    # Convert to lowercase (bash 3.x compatible)
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    [[ "$answer" == "y" || "$answer" == "yes" ]]
}

# Ask for selection from a list
# Usage: ask_select "prompt" "option1" "option2" ...
# Returns: selected option index (0-based)
ask_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local selection

    echo -e "\n${BOLD}$prompt${RESET}"
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done

    while true; do
        read -rp "Enter selection (1-${#options[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#options[@]} )); then
            echo $((selection - 1))
            return 0
        fi
        log_warn "Invalid selection. Please enter a number between 1 and ${#options[@]}"
    done
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Get macOS version
get_macos_version() {
    sw_vers -productVersion
}

# Get CPU architecture
get_architecture() {
    uname -m
}

# Check if running on Apple Silicon
is_apple_silicon() {
    [[ "$(get_architecture)" == "arm64" ]]
}

# Get Homebrew prefix (different for Intel vs Apple Silicon)
get_brew_prefix() {
    if is_apple_silicon; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

# Source a file if it exists
source_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
        return 0
    fi
    return 1
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# Check if running in dry-run mode
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Execute command (or print if dry-run)
run_cmd() {
    if is_dry_run; then
        echo -e "${DIM}[DRY-RUN] Would execute: $*${RESET}"
        return 0
    fi
    "$@"
}

# Safe file copy with backup awareness
safe_copy() {
    local src="$1"
    local dest="$2"

    if is_dry_run; then
        echo -e "${DIM}[DRY-RUN] Would copy: $src -> $dest${RESET}"
        return 0
    fi

    cp "$src" "$dest"
}

# ============================================================================
# Progress Indicators
# ============================================================================

# Simple spinner for long-running commands
# Usage: run_with_spinner "message" command args...
run_with_spinner() {
    local message="$1"
    shift

    if is_dry_run; then
        echo -e "${DIM}[DRY-RUN] Would run: $*${RESET}"
        return 0
    fi

    local pid
    local spin='-\|/'
    local i=0

    # Run command in background
    "$@" &>/dev/null &
    pid=$!

    # Show spinner
    printf "%s " "$message"
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r%s %s" "$message" "${spin:$i:1}"
        sleep 0.1
    done

    # Wait for command and check exit status
    if wait "$pid"; then
        printf "\r%s ${GREEN}done${RESET}\n" "$message"
        return 0
    else
        printf "\r%s ${RED}failed${RESET}\n" "$message"
        return 1
    fi
}

# ============================================================================
# Version Comparison
# ============================================================================

# Compare two version strings
# Returns: 0 if v1 >= v2, 1 otherwise
version_gte() {
    local v1="$1"
    local v2="$2"

    # Use sort -V for version comparison
    [[ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]]
}
