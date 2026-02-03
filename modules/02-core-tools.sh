#!/usr/bin/env bash
# 02-core-tools.sh - Install core shell and tmux tools
# Installs: tmux, fzf, fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting, oh-my-posh

set -euo pipefail

MODULE_NAME="core-tools"
MODULE_DESC="Core shell and tmux tools"

# Tools to install via Homebrew
CORE_FORMULAS=(
    "tmux"
    "fzf"
    "fzf-tab"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "oh-my-posh"
)

run_module() {
    log_step "Installing core tools"

    # Ensure Homebrew is available
    if ! command_exists brew; then
        log_error "Homebrew not found. Please run 01-homebrew.sh first."
        exit 1
    fi

    # Install each formula
    for formula in "${CORE_FORMULAS[@]}"; do
        brew_install "$formula"
    done

    # Run fzf post-install if needed
    setup_fzf

    log_success "Core tools installed"

    # Print summary
    print_tools_summary
}

setup_fzf() {
    log_substep "Configuring fzf"

    # fzf install script for key bindings (optional, since we source it in zshrc)
    local fzf_install
    fzf_install="$(brew --prefix)/opt/fzf/install"

    if [[ -x "$fzf_install" ]]; then
        log_debug "fzf install script found at: $fzf_install"
        # Note: We configure fzf manually in zshrc, so we don't run the install script
        # which would modify shell configs. Instead, zshrc sources the plugin directly.
        log_success "fzf configured (sourced via zshrc)"
    fi
}

print_tools_summary() {
    echo -e "\n${BOLD}Installed Tools:${RESET}"

    for formula in "${CORE_FORMULAS[@]}"; do
        if brew_is_installed "$formula"; then
            local version
            version=$(brew_get_version "$formula")
            echo -e "  ${GREEN}✓${RESET} $formula ($version)"
        else
            echo -e "  ${RED}✗${RESET} $formula (not installed)"
        fi
    done
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
