#!/usr/bin/env bash
# 03-zsh-base.sh - Oh-My-Zsh installation
# Installs Oh-My-Zsh framework if not present

set -euo pipefail

MODULE_NAME="zsh-base"
MODULE_DESC="Oh-My-Zsh installation"

run_module() {
    log_step "Setting up Oh-My-Zsh"

    # Check if zsh is the default shell
    check_default_shell

    # Install Oh-My-Zsh
    install_oh_my_zsh

    # Deploy standard zshrc template
    deploy_zshrc_template

    # Deploy $ZSH_CUSTOM config files
    deploy_custom_configs

    # Deploy ideavimrc
    deploy_ideavimrc

    log_success "Oh-My-Zsh ready"
}

check_default_shell() {
    log_substep "Checking default shell"

    local current_shell
    current_shell=$(dscl . -read ~/ UserShell | awk '{print $2}')

    if [[ "$current_shell" == *"zsh"* ]]; then
        log_success "Default shell is zsh"
        return 0
    fi

    log_warn "Current shell is $current_shell"

    if ! ask_yes_no "Change default shell to zsh?"; then
        log_info "Keeping current shell"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would change shell to zsh"
        return 0
    fi

    chsh -s /bin/zsh
    log_success "Default shell changed to zsh"
}

install_oh_my_zsh() {
    log_substep "Checking Oh-My-Zsh"

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        local version
        version=$(detect_oh_my_zsh)
        log_success "Oh-My-Zsh already installed ($version)"

        # Optionally update
        if [[ "${UPDATE_OMZ:-false}" == "true" ]]; then
            update_oh_my_zsh
        fi
        return 0
    fi

    log_info "Installing Oh-My-Zsh"

    if is_dry_run; then
        log_info "[DRY-RUN] Would install Oh-My-Zsh"
        return 0
    fi

    # Backup existing .zshrc if present
    if [[ -f "$HOME/.zshrc" ]]; then
        backup_file "$HOME/.zshrc" "existing zshrc before oh-my-zsh install"
    fi

    # Install Oh-My-Zsh (RUNZSH=no prevents it from launching a new shell)
    # KEEP_ZSHRC=yes prevents it from overwriting existing .zshrc
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    log_success "Oh-My-Zsh installed"
}

deploy_zshrc_template() {
    log_substep "Deploying standard zshrc template"

    local template="$SCRIPT_DIR/configs/zshrc.template"
    local zshrc="$HOME/.zshrc"

    if [[ ! -f "$template" ]]; then
        log_warn "zshrc.template not found at $template, skipping"
        return 0
    fi

    # Check if already deployed (compare content)
    if [[ -f "$zshrc" ]] && diff -q "$template" "$zshrc" &>/dev/null; then
        log_success "zshrc template already deployed"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would deploy zshrc template to $zshrc"
        return 0
    fi

    # Backup existing .zshrc before overwriting
    if [[ -f "$zshrc" ]]; then
        backup_file "$zshrc" "before deploying zshrc template"
    fi

    cp "$template" "$zshrc"
    log_success "zshrc template deployed"
}

update_oh_my_zsh() {
    log_substep "Updating Oh-My-Zsh"

    if is_dry_run; then
        log_info "[DRY-RUN] Would update Oh-My-Zsh"
        return 0
    fi

    # Run omz update command
    if [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
        zsh -c 'source ~/.oh-my-zsh/tools/upgrade.sh' 2>/dev/null || true
        log_success "Oh-My-Zsh updated"
    fi
}

deploy_custom_configs() {
    log_substep "Deploying \$ZSH_CUSTOM configs"

    local custom_dir="$HOME/.oh-my-zsh/custom"
    local configs_custom="$SCRIPT_DIR/configs/custom"

    if [[ ! -d "$configs_custom" ]]; then
        log_warn "configs/custom/ not found, skipping"
        return 0
    fi

    ensure_dir "$custom_dir"

    # Deploy shared configs (.zsh files) directly
    local f
    for f in "$configs_custom"/*.zsh; do
        [[ -f "$f" ]] || continue
        local basename
        basename=$(basename "$f")
        local dest="$custom_dir/$basename"

        if [[ -f "$dest" ]] && diff -q "$f" "$dest" &>/dev/null; then
            log_debug "$basename already up-to-date in \$ZSH_CUSTOM, skipping"
            continue
        fi

        if is_dry_run; then
            log_info "[DRY-RUN] Would deploy $basename to \$ZSH_CUSTOM/"
            continue
        fi

        if [[ -f "$dest" ]]; then
            backup_file "$dest" "before updating $basename"
        fi

        cp "$f" "$dest"
        log_substep "Deployed $basename"
    done

    # Deploy template configs (.zsh.template files) with interactive fill
    for f in "$configs_custom"/*.zsh.template; do
        [[ -f "$f" ]] || continue
        local basename
        basename=$(basename "$f")
        local target_name="${basename%.template}"
        local dest="$custom_dir/$target_name"

        # Skip if already deployed (either as .zsh or .zsh.template)
        if [[ -f "$dest" ]] || [[ -f "$custom_dir/$basename" ]]; then
            log_debug "$target_name already exists in \$ZSH_CUSTOM, skipping"
            continue
        fi

        if is_dry_run; then
            log_info "[DRY-RUN] Would deploy $basename to \$ZSH_CUSTOM/"
            continue
        fi

        # Detect placeholders
        local placeholders
        placeholders=$(grep -oE '__[A-Z_]+__' "$f" | sort -u || true)

        if [[ -z "$placeholders" ]]; then
            # No placeholders, deploy directly as .zsh
            cp "$f" "$dest"
            log_substep "Deployed $target_name"
            continue
        fi

        # Interactive fill
        log_info "Configuring $target_name:"
        local content
        content=$(cat "$f")
        local all_filled=true

        for placeholder in $placeholders; do
            local var_name="${placeholder//__/}"
            local user_value=""
            read -rp "  Enter value for $var_name (or press Enter to skip): " user_value

            if [[ -n "$user_value" ]]; then
                content="${content//$placeholder/$user_value}"
            else
                all_filled=false
            fi
        done

        if [[ "$all_filled" == "true" ]]; then
            echo "$content" > "$dest"
            log_substep "Deployed $target_name (configured)"
        else
            # Save as .template so Oh-My-Zsh won't source it
            cp "$f" "$custom_dir/$basename"
            log_substep "Saved $basename (unconfigured — edit and rename to .zsh to activate)"
        fi
    done

    log_success "\$ZSH_CUSTOM configs deployed"
}

deploy_ideavimrc() {
    log_substep "Deploying ideavimrc"

    local src="$SCRIPT_DIR/configs/ideavimrc"
    local dest="$HOME/.ideavimrc"

    if [[ ! -f "$src" ]]; then
        log_debug "configs/ideavimrc not found, skipping"
        return 0
    fi

    if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
        log_success "ideavimrc already deployed"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would deploy ideavimrc to $dest"
        return 0
    fi

    if [[ -f "$dest" ]]; then
        backup_file "$dest" "before deploying ideavimrc"
    fi

    cp "$src" "$dest"
    log_success "ideavimrc deployed"
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
