# mds — mac-dev-setup CLI helper
# Deployed to $ZSH_CUSTOM/mds.zsh by mac-dev-setup

mds() {
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    case "${1:-}" in
        custom)
            shift
            _mds_custom "$@"
            ;;
        help|--help|-h|"")
            _mds_help
            ;;
        *)
            echo "Unknown command: $1"
            _mds_help
            return 1
            ;;
    esac
}

_mds_help() {
    cat <<'EOF'
Usage: mds <command> [args]

Commands:
  custom list              List all $ZSH_CUSTOM configs and status
  custom edit <name>       Fill placeholders in a template and activate it
  custom enable <name>     Activate a .template config (rename to .zsh)
  custom disable <name>    Deactivate a config (rename back to .template)
  custom show <name>       Show contents of a config
  help                     Show this help
EOF
}

_mds_custom() {
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    case "${1:-}" in
        list|ls)    _mds_custom_list "$custom_dir" ;;
        edit)       _mds_custom_edit "$custom_dir" "${2:-}" ;;
        enable)     _mds_custom_enable "$custom_dir" "${2:-}" ;;
        disable)    _mds_custom_disable "$custom_dir" "${2:-}" ;;
        show|cat)   _mds_custom_show "$custom_dir" "${2:-}" ;;
        *)
            echo "Usage: mds custom <list|edit|enable|disable|show> [name]"
            return 1
            ;;
    esac
}

_mds_custom_list() {
    local custom_dir="$1"
    echo "ZSH_CUSTOM configs ($custom_dir):"
    echo ""

    local found=false

    # Active configs (.zsh files, excluding oh-my-zsh defaults)
    local f
    for f in "$custom_dir"/*.zsh; do
        [[ -f "$f" ]] || continue
        local name=$(basename "$f" .zsh)
        [[ "$name" == "example" ]] && continue
        echo "  \033[0;32m●\033[0m $name  (active)"
        found=true
    done

    # Inactive templates (.zsh.template files)
    for f in "$custom_dir"/*.zsh.template; do
        [[ -f "$f" ]] || continue
        local name=$(basename "$f" .zsh.template)
        # Check if placeholders remain
        if grep -qE '__[A-Z_]+__' "$f"; then
            echo "  \033[0;33m○\033[0m $name  (template — needs configuration)"
        else
            echo "  \033[0;90m○\033[0m $name  (inactive)"
        fi
        found=true
    done

    if [[ "$found" == "false" ]]; then
        echo "  (none)"
    fi
}

_mds_custom_edit() {
    local custom_dir="$1"
    local name="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: mds custom edit <name>"
        echo "Available:"
        local f
        for f in "$custom_dir"/*.zsh "$custom_dir"/*.zsh.template; do
            [[ -f "$f" ]] || continue
            local bn=$(basename "$f")
            [[ "$bn" == "example.zsh" ]] && continue
            local n="${bn%.zsh.template}"; n="${n%.zsh}"
            echo "  $n"
        done
        return 1
    fi

    local template="$custom_dir/${name}.zsh.template"
    local dest="$custom_dir/${name}.zsh"

    # If already activated, open in editor
    if [[ -f "$dest" ]] && [[ ! -f "$template" ]]; then
        echo "Opening $name in ${EDITOR:-vi}..."
        ${EDITOR:-vi} "$dest"
        return $?
    fi

    if [[ ! -f "$template" ]]; then
        echo "Not found: $name"
        return 1
    fi

    # Detect placeholders
    local placeholders
    placeholders=$(grep -oE '__[A-Z_]+__' "$template" | sort -u)

    if [[ -z "$placeholders" ]]; then
        echo "No placeholders found in $name. Use 'mds custom enable $name' to activate."
        return 0
    fi

    echo "Configuring $name:"
    echo ""

    local content
    content=$(cat "$template")
    local all_filled=true

    for placeholder in $placeholders; do
        # Strip leading/trailing __
        local var_name="${placeholder#__}"
        var_name="${var_name%__}"

        local user_value=""
        echo -n "  $var_name: "
        read -r user_value

        if [[ -n "$user_value" ]]; then
            content="${content//$placeholder/$user_value}"
        else
            echo "    (skipped)"
            all_filled=false
        fi
    done

    echo ""

    if [[ "$all_filled" == "true" ]]; then
        echo "$content" > "$dest"
        rm "$template"
        echo "✓ $name configured and activated. Restart shell or run: source $dest"
    else
        echo "$content" > "$template"
        echo "⚠ Some placeholders were skipped. Template updated but not activated."
        echo "  Run 'mds custom edit $name' again to fill remaining values."
    fi
}

_mds_custom_enable() {
    local custom_dir="$1"
    local name="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: mds custom enable <name>"
        return 1
    fi

    local template="$custom_dir/${name}.zsh.template"
    local dest="$custom_dir/${name}.zsh"

    if [[ -f "$dest" ]]; then
        echo "$name is already active."
        return 0
    fi

    if [[ ! -f "$template" ]]; then
        echo "Not found: $template"
        return 1
    fi

    # Warn if placeholders remain
    if grep -qE '__[A-Z_]+__' "$template"; then
        echo "⚠ Warning: $name still has unfilled placeholders:"
        grep -oE '__[A-Z_]+__' "$template" | sort -u | sed 's/^/    /'
        echo ""
        echo -n "Activate anyway? [y/N] "
        read -r answer
        [[ "$answer" == [yY]* ]] || return 0
    fi

    mv "$template" "$dest"
    echo "✓ $name activated. Restart shell or run: source $dest"
}

_mds_custom_disable() {
    local custom_dir="$1"
    local name="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: mds custom disable <name>"
        return 1
    fi

    local src="$custom_dir/${name}.zsh"
    local dest="$custom_dir/${name}.zsh.template"

    if [[ ! -f "$src" ]]; then
        echo "$name is not active."
        return 1
    fi

    mv "$src" "$dest"
    echo "✓ $name deactivated. Restart shell to take effect."
}

_mds_custom_show() {
    local custom_dir="$1"
    local name="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: mds custom show <name>"
        return 1
    fi

    local file=""
    if [[ -f "$custom_dir/${name}.zsh" ]]; then
        file="$custom_dir/${name}.zsh"
    elif [[ -f "$custom_dir/${name}.zsh.template" ]]; then
        file="$custom_dir/${name}.zsh.template"
    else
        echo "Not found: $name"
        return 1
    fi

    echo "--- $(basename "$file") ---"
    cat "$file"
}
