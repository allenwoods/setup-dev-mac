#!/usr/bin/env bash
# 07-fonts.sh - Nerd Fonts installation
# Installs Nerd Fonts for proper terminal icon display

set -euo pipefail

MODULE_NAME="fonts"
MODULE_DESC="Nerd Fonts installation"

# Default fonts to install
DEFAULT_FONTS=(
    "hack"
    "meslo-lg"
    "fira-code"
)

# Minimal fonts (just one good option)
MINIMAL_FONTS=(
    "meslo-lg"
)

run_module() {
    log_step "Installing Nerd Fonts"

    # Check if any Nerd Font is already installed
    if detect_nerd_font; then
        log_success "Nerd Font already installed"

        if ! ask_yes_no "Install additional Nerd Fonts?"; then
            return 0
        fi
    fi

    # Choose installation mode
    local install_mode
    if [[ "${MINIMAL_INSTALL:-false}" == "true" ]]; then
        install_mode="minimal"
    else
        install_mode=$(choose_install_mode)
    fi

    case "$install_mode" in
        minimal)
            install_fonts "${MINIMAL_FONTS[@]}"
            ;;
        full)
            install_fonts "${DEFAULT_FONTS[@]}"
            ;;
        skip)
            log_info "Skipping font installation"
            return 0
            ;;
    esac

    log_success "Nerd Fonts installed"
    print_font_instructions
}

choose_install_mode() {
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        echo "minimal"
        return 0
    fi

    echo ""
    echo -e "${BOLD}Font installation options:${RESET}"
    echo "  1) Minimal - Install MesloLG Nerd Font only (recommended)"
    echo "  2) Full    - Install Hack, MesloLG, and FiraCode Nerd Fonts"
    echo "  3) Skip    - Don't install fonts"
    echo ""

    local choice
    read -rp "Choice [1]: " choice
    choice="${choice:-1}"

    case "$choice" in
        1) echo "minimal" ;;
        2) echo "full" ;;
        3) echo "skip" ;;
        *) echo "minimal" ;;
    esac
}

install_fonts() {
    local fonts=("$@")

    log_substep "Installing fonts: ${fonts[*]}"

    for font in "${fonts[@]}"; do
        install_nerd_font "$font"
    done
}

install_nerd_font() {
    local font_name="$1"
    local cask_name="font-${font_name}-nerd-font"

    # Check if already installed
    if brew_cask_is_installed "$cask_name"; then
        log_success "$font_name Nerd Font already installed"
        return 0
    fi

    log_substep "Installing $font_name Nerd Font"

    if is_dry_run; then
        log_info "[DRY-RUN] Would install $cask_name"
        return 0
    fi

    # Ensure cask-fonts tap is available
    # Note: As of 2024, fonts are in homebrew/cask directly, but we check anyway
    if ! brew tap | grep -q "homebrew/cask-fonts"; then
        # This may not be needed for newer Homebrew versions
        log_debug "Tapping homebrew/cask-fonts (if needed)"
        brew tap homebrew/cask-fonts 2>/dev/null || true
    fi

    brew install --cask "$cask_name"
    log_success "$font_name Nerd Font installed"
}

print_font_instructions() {
    echo ""
    echo -e "${BOLD}Font Configuration:${RESET}"
    echo "To use Nerd Fonts in your terminal, configure your terminal app:"
    echo ""
    echo "  iTerm2:   Preferences -> Profiles -> Text -> Font"
    echo "  Terminal: Preferences -> Profiles -> Font"
    echo "  VS Code:  Settings -> Terminal.Integrated.Font.Family"
    echo ""
    echo "Recommended fonts:"
    echo "  - MesloLGS NF (best for Powerline/Nerd symbols)"
    echo "  - Hack Nerd Font (clean and readable)"
    echo "  - FiraCode Nerd Font (with ligatures)"
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
