#!/usr/bin/env bash
# 05-oh-my-posh.sh - Oh-My-Posh prompt configuration
# Configures Oh-My-Posh with di4am0nd theme

set -euo pipefail

MODULE_NAME="oh-my-posh"
MODULE_DESC="Oh-My-Posh prompt theme"

# Default theme
DEFAULT_THEME="di4am0nd"

run_module() {
    log_step "Configuring Oh-My-Posh"

    # Check if oh-my-posh is installed
    if ! command_exists oh-my-posh; then
        log_error "oh-my-posh not found. Please run 02-core-tools.sh first."
        exit 1
    fi

    # Configure in zshrc
    configure_oh_my_posh

    # Disable Oh-My-Zsh theme (since we're using Oh-My-Posh)
    disable_omz_theme

    log_success "Oh-My-Posh configured with $DEFAULT_THEME theme"
}

configure_oh_my_posh() {
    log_substep "Configuring Oh-My-Posh in zshrc"

    local zshrc="$HOME/.zshrc"
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    # Expected configuration line
    local omp_config='eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/'"$DEFAULT_THEME"'.omp.json)"'

    # Check if already configured
    if grep -q "oh-my-posh init zsh" "$zshrc"; then
        # Check if using correct theme
        if grep -q "$DEFAULT_THEME" "$zshrc"; then
            log_success "Oh-My-Posh already configured with $DEFAULT_THEME theme"
            return 0
        else
            log_info "Oh-My-Posh configured with different theme"
            if ! ask_yes_no "Update to $DEFAULT_THEME theme?"; then
                return 0
            fi
        fi
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would add Oh-My-Posh configuration"
        return 0
    fi

    # Backup before modification
    backup_file "$zshrc" "before oh-my-posh configuration"

    # Remove existing oh-my-posh config if present
    if grep -q "oh-my-posh init" "$zshrc"; then
        sed -i '' '/oh-my-posh init/d' "$zshrc"
        # Also remove comment line above it if present
        sed -i '' '/# Oh My Posh configuration/d' "$zshrc"
    fi

    # Add Oh-My-Posh configuration after oh-my-zsh source
    # We add it right after the oh-my-zsh.sh source line
    local temp_file
    temp_file=$(mktemp)

    while IFS= read -r line; do
        echo "$line" >> "$temp_file"
        if [[ "$line" == *"source \$ZSH/oh-my-zsh.sh"* || "$line" == *"source \"\$ZSH/oh-my-zsh.sh\""* ]]; then
            echo "" >> "$temp_file"
            echo "# Oh My Posh configuration ($DEFAULT_THEME theme)" >> "$temp_file"
            echo "$omp_config" >> "$temp_file"
        fi
    done < "$zshrc"

    mv "$temp_file" "$zshrc"
    log_success "Oh-My-Posh configuration added"
}

disable_omz_theme() {
    log_substep "Disabling Oh-My-Zsh theme"

    local zshrc="$HOME/.zshrc"

    # Check if ZSH_THEME is already empty
    if grep -qE '^ZSH_THEME=""' "$zshrc"; then
        log_debug "Oh-My-Zsh theme already disabled"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would disable Oh-My-Zsh theme"
        return 0
    fi

    # Replace ZSH_THEME line with empty value
    if grep -q '^ZSH_THEME=' "$zshrc"; then
        sed -i '' 's/^ZSH_THEME=.*/ZSH_THEME=""/' "$zshrc"
        # Add comment explaining why it's disabled
        if ! grep -q "using Oh My Posh instead" "$zshrc"; then
            sed -i '' '/^ZSH_THEME=""/i\
# Disable oh-my-zsh theme (using Oh My Posh instead)
' "$zshrc"
        fi
        log_substep "Disabled Oh-My-Zsh theme"
    fi
}

# Show available themes
list_themes() {
    local brew_prefix
    brew_prefix=$(brew --prefix oh-my-posh)
    local themes_dir="$brew_prefix/themes"

    echo -e "\n${BOLD}Available Oh-My-Posh themes:${RESET}"
    ls "$themes_dir"/*.omp.json 2>/dev/null | xargs -n1 basename | sed 's/.omp.json$//' | column
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
