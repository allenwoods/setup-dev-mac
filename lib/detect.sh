#!/usr/bin/env bash
# detect.sh - Detection functions for existing configurations
# Checks for installed tools and existing configuration files

# Note: This file should be sourced after common.sh
# Functions will work even if common.sh logging isn't available

# ============================================================================
# Tool Detection
# ============================================================================

detect_homebrew() {
    if command_exists brew; then
        local version
        version=$(brew --version | head -n1 | awk '{print $2}')
        echo "$version"
        return 0
    fi
    return 1
}

detect_zsh() {
    if command_exists zsh; then
        zsh --version | awk '{print $2}'
        return 0
    fi
    return 1
}

detect_tmux() {
    if command_exists tmux; then
        tmux -V | awk '{print $2}'
        return 0
    fi
    return 1
}

detect_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        # Try to get version from git
        if [[ -d "$HOME/.oh-my-zsh/.git" ]]; then
            git -C "$HOME/.oh-my-zsh" describe --tags 2>/dev/null || echo "installed"
        else
            echo "installed"
        fi
        return 0
    fi
    return 1
}

detect_oh_my_posh() {
    if command_exists oh-my-posh; then
        oh-my-posh --version 2>/dev/null || echo "installed"
        return 0
    fi
    return 1
}

detect_oh_my_tmux() {
    local omt_paths=(
        "$HOME/.local/share/tmux/oh-my-tmux"
        "$HOME/.tmux"
    )

    for path in "${omt_paths[@]}"; do
        if [[ -d "$path" && -f "$path/.tmux.conf" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

detect_fzf() {
    if command_exists fzf; then
        fzf --version | awk '{print $1}'
        return 0
    fi
    return 1
}

detect_node() {
    if command_exists node; then
        node --version | sed 's/^v//'
        return 0
    fi
    return 1
}

detect_uv() {
    if command_exists uv; then
        uv --version | awk '{print $2}'
        return 0
    fi
    return 1
}

# ============================================================================
# Configuration Detection
# ============================================================================

# Detect zsh configuration files
detect_zshrc() {
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        echo "$zshrc"
        return 0
    fi
    return 1
}

# Check if Oh-My-Posh is configured in zshrc
detect_zshrc_has_omp() {
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]] && grep -q "oh-my-posh init" "$zshrc"; then
        return 0
    fi
    return 1
}

# Check if specific zsh plugin is enabled
detect_zsh_plugin() {
    local plugin="$1"
    local zshrc="$HOME/.zshrc"

    if [[ -f "$zshrc" ]] && grep -qE "^\s*plugins=.*\b$plugin\b" "$zshrc"; then
        return 0
    fi
    return 1
}

# Detect tmux configuration
detect_tmux_config() {
    local config_paths=(
        "$HOME/.config/tmux/tmux.conf"
        "$HOME/.tmux.conf"
    )

    for path in "${config_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Detect tmux local configuration (for oh-my-tmux)
detect_tmux_local_config() {
    local config_paths=(
        "$HOME/.config/tmux/tmux.conf.local"
        "$HOME/.tmux.conf.local"
    )

    for path in "${config_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Check if tmux config uses Solarized Dark theme
detect_tmux_solarized_dark() {
    local config
    config=$(detect_tmux_local_config)

    if [[ -n "$config" ]] && grep -q "Solarized Dark" "$config"; then
        return 0
    fi
    return 1
}

# ============================================================================
# Font Detection
# ============================================================================

# Check if a Nerd Font is installed
detect_nerd_font() {
    local font_name="${1:-}"
    local font_dirs=(
        "$HOME/Library/Fonts"
        "/Library/Fonts"
    )

    for dir in "${font_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -n "$font_name" ]]; then
                # Check for specific font
                if ls "$dir"/*"$font_name"*Nerd* 2>/dev/null | head -n1 | grep -q .; then
                    return 0
                fi
            else
                # Check for any Nerd Font
                if ls "$dir"/*Nerd* 2>/dev/null | head -n1 | grep -q .; then
                    return 0
                fi
            fi
        fi
    done
    return 1
}

# ============================================================================
# System Detection
# ============================================================================

# Check if Xcode CLI tools are installed
detect_xcode_cli() {
    if xcode-select -p &>/dev/null; then
        echo "installed"
        return 0
    fi
    return 1
}

# Check if running in Rosetta (Intel emulation on Apple Silicon)
detect_rosetta() {
    if [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" == "1" ]]; then
        return 0
    fi
    return 1
}

# ============================================================================
# Summary Functions
# ============================================================================

# Print a detection summary
print_detection_summary() {
    log_step "Detection Summary"

    echo -e "\n${BOLD}System:${RESET}"
    echo "  macOS:        $(get_macos_version)"
    echo "  Architecture: $(get_architecture)"
    if detect_rosetta; then
        echo "  Rosetta:      running under translation"
    fi

    echo -e "\n${BOLD}Core Tools:${RESET}"
    local tool version
    for tool in homebrew zsh tmux fzf; do
        if version=$(detect_$tool 2>/dev/null); then
            echo -e "  $tool: ${GREEN}$version${RESET}"
        else
            echo -e "  $tool: ${RED}not installed${RESET}"
        fi
    done

    echo -e "\n${BOLD}Shell Enhancements:${RESET}"
    for tool in oh_my_zsh oh_my_posh; do
        if version=$(detect_$tool 2>/dev/null); then
            echo -e "  ${tool//_/-}: ${GREEN}$version${RESET}"
        else
            echo -e "  ${tool//_/-}: ${RED}not installed${RESET}"
        fi
    done

    echo -e "\n${BOLD}Development Tools:${RESET}"
    for tool in node uv; do
        if version=$(detect_$tool 2>/dev/null); then
            echo -e "  $tool: ${GREEN}$version${RESET}"
        else
            echo -e "  $tool: ${DIM}not installed${RESET}"
        fi
    done

    echo -e "\n${BOLD}Tmux Configuration:${RESET}"
    if path=$(detect_oh_my_tmux 2>/dev/null); then
        echo -e "  oh-my-tmux: ${GREEN}$path${RESET}"
    else
        echo -e "  oh-my-tmux: ${RED}not installed${RESET}"
    fi

    if detect_tmux_solarized_dark; then
        echo -e "  Theme: ${GREEN}Solarized Dark${RESET}"
    fi

    echo -e "\n${BOLD}Fonts:${RESET}"
    if detect_nerd_font; then
        echo -e "  Nerd Font: ${GREEN}installed${RESET}"
    else
        echo -e "  Nerd Font: ${RED}not installed${RESET}"
    fi
}
