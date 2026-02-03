#!/usr/bin/env bash
# 06-tmux.sh - Tmux + Oh-My-Tmux + Solarized Dark theme
# Installs Oh-My-Tmux and configures Solarized Dark theme

set -euo pipefail

MODULE_NAME="tmux"
MODULE_DESC="Tmux configuration with Oh-My-Tmux"

# Oh-My-Tmux installation path (XDG compliant)
OMT_INSTALL_DIR="$HOME/.local/share/tmux/oh-my-tmux"
OMT_REPO="https://github.com/gpakosz/.tmux.git"

# Configuration paths
TMUX_CONFIG_DIR="$HOME/.config/tmux"
TMUX_CONF="$TMUX_CONFIG_DIR/tmux.conf"
TMUX_LOCAL_CONF="$TMUX_CONFIG_DIR/tmux.conf.local"

run_module() {
    log_step "Configuring Tmux with Oh-My-Tmux"

    # Check if tmux is installed
    if ! command_exists tmux; then
        log_error "tmux not found. Please run 02-core-tools.sh first."
        exit 1
    fi

    # Install Oh-My-Tmux
    install_oh_my_tmux

    # Configure tmux.conf
    configure_tmux_conf

    # Configure tmux.conf.local with Solarized Dark
    configure_tmux_local

    log_success "Tmux configured with Oh-My-Tmux and Solarized Dark theme"
}

install_oh_my_tmux() {
    log_substep "Installing Oh-My-Tmux"

    # Check if already installed
    if [[ -d "$OMT_INSTALL_DIR" && -f "$OMT_INSTALL_DIR/.tmux.conf" ]]; then
        log_success "Oh-My-Tmux already installed at $OMT_INSTALL_DIR"

        # Optionally update
        if [[ "${UPDATE_OMT:-false}" == "true" ]]; then
            update_oh_my_tmux
        fi
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would install Oh-My-Tmux to $OMT_INSTALL_DIR"
        return 0
    fi

    # Create parent directory
    ensure_dir "$(dirname "$OMT_INSTALL_DIR")"

    # Clone Oh-My-Tmux
    git clone "$OMT_REPO" "$OMT_INSTALL_DIR"

    log_success "Oh-My-Tmux installed"
}

update_oh_my_tmux() {
    log_substep "Updating Oh-My-Tmux"

    if is_dry_run; then
        log_info "[DRY-RUN] Would update Oh-My-Tmux"
        return 0
    fi

    git -C "$OMT_INSTALL_DIR" pull
    log_success "Oh-My-Tmux updated"
}

configure_tmux_conf() {
    log_substep "Configuring tmux.conf"

    # Create config directory
    ensure_dir "$TMUX_CONFIG_DIR"

    # Backup existing config
    if [[ -f "$TMUX_CONF" ]]; then
        backup_file "$TMUX_CONF" "existing tmux.conf"
    fi

    # Check if already linked correctly
    if [[ -L "$TMUX_CONF" ]]; then
        local link_target
        link_target=$(readlink "$TMUX_CONF")
        if [[ "$link_target" == "$OMT_INSTALL_DIR/.tmux.conf" ]]; then
            log_success "tmux.conf already linked to Oh-My-Tmux"
            return 0
        fi
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would create symlink: $TMUX_CONF -> $OMT_INSTALL_DIR/.tmux.conf"
        return 0
    fi

    # Remove existing and create symlink
    rm -f "$TMUX_CONF"
    ln -s "$OMT_INSTALL_DIR/.tmux.conf" "$TMUX_CONF"

    log_success "tmux.conf linked to Oh-My-Tmux"
}

configure_tmux_local() {
    log_substep "Configuring tmux.conf.local with Solarized Dark"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local template="$script_dir/configs/tmux.conf.local.template"

    # Check if already using Solarized Dark
    if [[ -f "$TMUX_LOCAL_CONF" ]] && grep -q "Solarized Dark" "$TMUX_LOCAL_CONF"; then
        log_success "tmux.conf.local already configured with Solarized Dark"

        if ! ask_yes_no "Overwrite existing configuration?"; then
            return 0
        fi
    fi

    # Backup existing config
    if [[ -f "$TMUX_LOCAL_CONF" ]]; then
        backup_file "$TMUX_LOCAL_CONF" "existing tmux.conf.local"
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would copy Solarized Dark template to $TMUX_LOCAL_CONF"
        return 0
    fi

    # Copy template
    if [[ -f "$template" ]]; then
        cp "$template" "$TMUX_LOCAL_CONF"
        log_success "Solarized Dark theme applied"
    else
        log_warn "Template not found: $template"
        log_info "Creating minimal tmux.conf.local"
        create_minimal_local_conf
    fi
}

create_minimal_local_conf() {
    cat > "$TMUX_LOCAL_CONF" << 'EOF'
# tmux.conf.local - Oh My Tmux local configuration
# Solarized Dark theme

# -- theming -------------------------------------------------------------------
tmux_conf_theme=enabled

# Solarized Dark colors
tmux_conf_theme_colour_1="#002b36"    # base03
tmux_conf_theme_colour_2="#073642"    # base02
tmux_conf_theme_colour_3="#586e75"    # base01
tmux_conf_theme_colour_4="#268bd2"    # blue
tmux_conf_theme_colour_5="#b58900"    # yellow
tmux_conf_theme_colour_6="#002b36"    # base03
tmux_conf_theme_colour_7="#839496"    # base0
tmux_conf_theme_colour_8="#002b36"    # base03
tmux_conf_theme_colour_9="#b58900"    # yellow
tmux_conf_theme_colour_10="#2aa198"   # cyan
tmux_conf_theme_colour_11="#859900"   # green
tmux_conf_theme_colour_12="#586e75"   # base01
tmux_conf_theme_colour_13="#93a1a1"   # base1
tmux_conf_theme_colour_14="#002b36"   # base03
tmux_conf_theme_colour_15="#073642"   # base02
tmux_conf_theme_colour_16="#dc322f"   # red
tmux_conf_theme_colour_17="#839496"   # base0

# Powerline separators
tmux_conf_theme_left_separator_main='\uE0B0'
tmux_conf_theme_left_separator_sub='\uE0B1'
tmux_conf_theme_right_separator_main='\uE0B2'
tmux_conf_theme_right_separator_sub='\uE0B3'
EOF
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
