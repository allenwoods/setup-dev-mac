#!/usr/bin/env bash
# 01-homebrew.sh - Homebrew installation and setup
# Installs Homebrew package manager if not present

set -euo pipefail

MODULE_NAME="homebrew"
MODULE_DESC="Homebrew package manager"

run_module() {
    log_step "Setting up Homebrew"

    if command_exists brew; then
        local version
        version=$(detect_homebrew)
        log_success "Homebrew already installed ($version)"

        # Ensure brew is in PATH for this session
        setup_brew_path

        # Update if requested
        if [[ "${UPDATE_BREW:-true}" == "true" ]]; then
            update_homebrew
        fi
    else
        install_homebrew
    fi

    # Print info
    if ! is_dry_run && command_exists brew; then
        brew_print_info
    fi

    log_success "Homebrew ready"
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
