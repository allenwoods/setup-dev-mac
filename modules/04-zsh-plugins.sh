#!/usr/bin/env bash
# 04-zsh-plugins.sh - Configure zsh plugins
# Sets up Oh-My-Zsh plugins in .zshrc

set -euo pipefail

MODULE_NAME="zsh-plugins"
MODULE_DESC="Zsh plugin configuration"

# Default plugin list (based on current machine configuration)
DEFAULT_PLUGINS=(
    "git"
    "docker"
    "docker-compose"
    "python"
    "virtualenv"
    "uv"
    "npm"
    "nvm"
    "z"
)

run_module() {
    log_step "Configuring zsh plugins"

    local zshrc="$HOME/.zshrc"

    # Check if .zshrc exists
    if [[ ! -f "$zshrc" ]]; then
        log_error ".zshrc not found. Please run 03-zsh-base.sh first."
        exit 1
    fi

    # Backup zshrc before modifications
    backup_file "$zshrc" "before plugin configuration"

    # Configure plugins
    configure_omz_plugins

    # Configure external plugins (from Homebrew)
    configure_external_plugins

    log_success "Zsh plugins configured"
}

configure_omz_plugins() {
    log_substep "Configuring Oh-My-Zsh plugins"

    local zshrc="$HOME/.zshrc"

    # Read current plugins from zshrc
    local current_plugins
    if grep -q "^plugins=(" "$zshrc"; then
        current_plugins=$(grep -A 20 "^plugins=(" "$zshrc" | grep -E "^\s+\w+" | tr -d ' ' | tr '\n' ' ')
        log_debug "Current plugins: $current_plugins"
    fi

    # Check if plugins need to be updated
    local needs_update=false
    for plugin in "${DEFAULT_PLUGINS[@]}"; do
        if ! grep -qE "^\s*$plugin\s*$" <(grep -A 20 "^plugins=(" "$zshrc"); then
            needs_update=true
            break
        fi
    done

    if [[ "$needs_update" == "false" ]]; then
        log_success "Oh-My-Zsh plugins already configured"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would update plugins to: ${DEFAULT_PLUGINS[*]}"
        return 0
    fi

    # Build new plugins block
    local plugins_block="plugins=(\n"
    for plugin in "${DEFAULT_PLUGINS[@]}"; do
        plugins_block+="  $plugin\n"
    done
    plugins_block+=")"

    # Replace plugins block in zshrc
    # This uses sed to replace the entire plugins=(...) block
    local temp_file
    temp_file=$(mktemp)

    awk '
        /^plugins=\(/ {
            # Found plugins block, skip until closing paren
            in_plugins = 1
            next
        }
        in_plugins && /^\)/ {
            in_plugins = 0
            next
        }
        !in_plugins {
            print
        }
    ' "$zshrc" > "$temp_file"

    # Find where to insert (after ZSH_CUSTOM or before source oh-my-zsh)
    if grep -q "^source.*oh-my-zsh.sh" "$temp_file"; then
        # Insert plugins block before source line
        sed -i '' '/^source.*oh-my-zsh.sh/i\
plugins=(\
  '"$(printf '%s\n  ' "${DEFAULT_PLUGINS[@]}" | sed 's/  $//')"'\
)\
' "$temp_file"
    fi

    mv "$temp_file" "$zshrc"
    log_success "Oh-My-Zsh plugins updated"
}

configure_external_plugins() {
    log_substep "Configuring external plugins"

    local zshrc="$HOME/.zshrc"
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    # External plugins to configure (sourced from Homebrew)
    # Using separate arrays for bash 3.x compatibility
    local plugin_names=(
        "fzf-tab"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
    )
    local plugin_paths=(
        "$brew_prefix/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
        "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    )

    local i=0
    for plugin in "${plugin_names[@]}"; do
        local source_path="${plugin_paths[$i]}"
        ((i++)) || true

        # Check if already configured
        if grep -q "$source_path" "$zshrc"; then
            log_debug "$plugin already configured in zshrc"
            continue
        fi

        if is_dry_run; then
            log_info "[DRY-RUN] Would add source for $plugin"
            continue
        fi

        # Add source line at the end of zshrc
        # Note: zsh-syntax-highlighting should be last
        echo "" >> "$zshrc"
        echo "# $plugin (Homebrew)" >> "$zshrc"
        echo "source \"$source_path\"" >> "$zshrc"

        log_substep "Added $plugin configuration"
    done

    log_success "External plugins configured"
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
