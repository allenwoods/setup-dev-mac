#!/usr/bin/env bash
# 99-finalize.sh - Final verification and cleanup
# Verifies installation and prints summary

set -euo pipefail

MODULE_NAME="finalize"
MODULE_DESC="Verification and cleanup"

run_module() {
    log_step "Finalizing installation"

    # Run verification
    verify_installation

    # Print backup summary
    print_backup_summary

    # Print final instructions
    print_final_instructions

    log_success "Setup complete!"
}

verify_installation() {
    log_substep "Verifying installation"

    local failed=0
    local passed=0

    echo ""
    echo -e "${BOLD}Verification Results:${RESET}"

    # Check core tools
    if verify_tool "zsh" "zsh --version | head -n1"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if verify_tool "tmux" "tmux -V"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if verify_tool "fzf" "fzf --version | head -n1"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if verify_tool "oh-my-posh" "oh-my-posh --version 2>/dev/null || echo 'installed'"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    # Check Oh-My-Zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "  ${GREEN}✓${RESET} oh-my-zsh: installed"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}✗${RESET} oh-my-zsh: not found"
        failed=$((failed + 1))
    fi

    # Check Oh-My-Tmux
    local omt_path
    if omt_path=$(detect_oh_my_tmux 2>/dev/null); then
        echo -e "  ${GREEN}✓${RESET} oh-my-tmux: $omt_path"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}✗${RESET} oh-my-tmux: not found"
        failed=$((failed + 1))
    fi

    # Check tmux config
    if [[ -f "$HOME/.config/tmux/tmux.conf.local" ]] && grep -q "Solarized" "$HOME/.config/tmux/tmux.conf.local"; then
        echo -e "  ${GREEN}✓${RESET} tmux theme: Solarized Dark"
        passed=$((passed + 1))
    elif [[ -f "$HOME/.config/tmux/tmux.conf.local" ]]; then
        echo -e "  ${YELLOW}○${RESET} tmux theme: custom (not Solarized)"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}✗${RESET} tmux theme: not configured"
        failed=$((failed + 1))
    fi

    # Check Nerd Font
    if detect_nerd_font; then
        echo -e "  ${GREEN}✓${RESET} nerd-font: installed"
        passed=$((passed + 1))
    else
        echo -e "  ${YELLOW}○${RESET} nerd-font: not installed (optional)"
    fi

    echo ""
    echo -e "Results: ${GREEN}$passed passed${RESET}, ${RED}$failed failed${RESET}"

    if [[ $failed -gt 0 ]]; then
        log_warn "Some components may not be properly installed"
        return 1
    fi

    return 0
}

verify_tool() {
    local name="$1"
    local check_cmd="$2"

    if command_exists "$name"; then
        local version
        version=$(eval "$check_cmd" 2>/dev/null | head -n1 || echo "installed")
        echo -e "  ${GREEN}✓${RESET} $name: $version"
        return 0
    else
        echo -e "  ${RED}✗${RESET} $name: not found"
        return 1
    fi
}

print_final_instructions() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  Setup Complete!${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${BOLD}Next Steps:${RESET}"
    echo ""
    echo "  1. Restart your terminal or run:"
    echo "     ${DIM}source ~/.zshrc${RESET}"
    echo ""
    echo "  2. Start tmux to see the new theme:"
    echo "     ${DIM}tmux${RESET}"
    echo ""
    echo "  3. If icons look broken, configure your terminal font to use"
    echo "     a Nerd Font (e.g., MesloLGS NF, Hack Nerd Font)"
    echo ""

    if [[ -n "${BACKUP_SESSION_DIR:-}" && -d "${BACKUP_SESSION_DIR:-}" ]]; then
        echo -e "${BOLD}Restore Previous Config:${RESET}"
        echo "  If something went wrong, restore your backup:"
        echo "  ${DIM}./install.sh --restore $(basename "$BACKUP_SESSION_DIR")${RESET}"
        echo ""
    fi

    echo -e "${BOLD}Quick Commands:${RESET}"
    echo "  ${DIM}# View tmux keybindings${RESET}"
    echo "  tmux list-keys"
    echo ""
    echo "  ${DIM}# Reload tmux config${RESET}"
    echo "  tmux source-file ~/.config/tmux/tmux.conf"
    echo ""
    echo "  ${DIM}# List oh-my-posh themes${RESET}"
    echo "  ls \$(brew --prefix oh-my-posh)/themes/"
    echo ""
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
