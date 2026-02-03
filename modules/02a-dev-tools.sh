#!/usr/bin/env bash
# 02a-dev-tools.sh - Optional development tools (interactive)
# Detects installed tools and offers to install missing ones: uv, node

set -euo pipefail

MODULE_NAME="dev-tools"
MODULE_DESC="Optional development tools"

# Development tools (parallel arrays for bash 3.x compatibility)
DEV_TOOL_NAMES=("uv" "node")
DEV_TOOL_DESCS=("Python package/project manager" "Node.js JavaScript runtime")

run_module() {
    log_step "Development Tools"

    # Ensure Homebrew is available
    if ! command_exists brew; then
        log_error "Homebrew not found. Please run 01-homebrew.sh first."
        exit 1
    fi

    # Detect installed tools
    local installed_tools=""
    local installed_versions=""
    local missing_tools=""

    detect_dev_tools

    # Show status report
    print_dev_tools_status

    # If nothing is missing, we're done
    if [[ -z "$missing_tools" ]]; then
        log_success "All development tools already installed"
        return 0
    fi

    # In non-interactive or auto-yes mode, skip
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        log_info "Skipping optional dev tools in non-interactive mode"
        return 0
    fi

    # Ask user what to install
    if is_dry_run; then
        log_info "[DRY-RUN] Would prompt for missing tools: $missing_tools"
        return 0
    fi

    prompt_install_tools
}

detect_dev_tools() {
    local i=0
    for tool in "${DEV_TOOL_NAMES[@]}"; do
        local version=""
        case "$tool" in
            uv)
                version=$(detect_uv 2>/dev/null) || true
                ;;
            node)
                version=$(detect_node 2>/dev/null) || true
                ;;
        esac

        if [[ -n "$version" ]]; then
            if [[ -n "$installed_tools" ]]; then
                installed_tools="$installed_tools $tool"
                installed_versions="$installed_versions $version"
            else
                installed_tools="$tool"
                installed_versions="$version"
            fi
        else
            if [[ -n "$missing_tools" ]]; then
                missing_tools="$missing_tools $tool"
            else
                missing_tools="$tool"
            fi
        fi
        ((i++)) || true
    done
}

get_tool_desc() {
    local tool="$1"
    local i=0
    for t in "${DEV_TOOL_NAMES[@]}"; do
        if [[ "$t" == "$tool" ]]; then
            echo "${DEV_TOOL_DESCS[$i]}"
            return 0
        fi
        ((i++)) || true
    done
    echo "Development tool"
}

print_dev_tools_status() {
    echo -e "\n${BOLD}Development Tools Status:${RESET}"

    # Print installed tools
    if [[ -n "$installed_tools" ]]; then
        local tools_arr=($installed_tools)
        local versions_arr=($installed_versions)
        local i=0
        for tool in "${tools_arr[@]}"; do
            local version="${versions_arr[$i]}"
            local desc
            desc=$(get_tool_desc "$tool")
            echo -e "  ${GREEN}✓${RESET} $tool - already installed ($version)"
            echo -e "    ${DIM}$desc${RESET}"
            ((i++)) || true
        done
    fi

    # Print missing tools
    if [[ -n "$missing_tools" ]]; then
        for tool in $missing_tools; do
            local desc
            desc=$(get_tool_desc "$tool")
            echo -e "  ${YELLOW}○${RESET} $tool - not installed"
            echo -e "    ${DIM}$desc${RESET}"
        done
    fi
}

prompt_install_tools() {
    echo ""
    echo -e "${BOLD}Install missing tools?${RESET}"
    echo "  Y) Install all missing tools ($missing_tools)"
    echo "  n) Skip"
    echo "  s) Select which tools to install"
    echo ""

    local answer
    read -rp "Choice [Y/n/s]: " answer
    answer="${answer:-Y}"

    # Convert to lowercase (bash 3.x compatible)
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
        y|yes)
            install_tools $missing_tools
            ;;
        s|select)
            select_and_install_tools $missing_tools
            ;;
        *)
            log_info "Skipping development tools installation"
            ;;
    esac
}

select_and_install_tools() {
    local tools=("$@")
    local to_install=""

    echo ""
    for tool in "${tools[@]}"; do
        local desc
        desc=$(get_tool_desc "$tool")
        if ask_yes_no "Install $tool ($desc)?"; then
            if [[ -n "$to_install" ]]; then
                to_install="$to_install $tool"
            else
                to_install="$tool"
            fi
        fi
    done

    if [[ -n "$to_install" ]]; then
        install_tools $to_install
    else
        log_info "No tools selected"
    fi
}

install_tools() {
    local tools=("$@")

    log_substep "Installing: ${tools[*]}"

    for tool in "${tools[@]}"; do
        install_dev_tool "$tool"
    done
}

install_dev_tool() {
    local tool="$1"

    case "$tool" in
        uv)
            brew_install "uv"
            ;;
        node)
            # Use nvm or direct node - we'll use direct for simplicity
            brew_install "node"
            ;;
        *)
            log_warn "Unknown tool: $tool"
            return 1
            ;;
    esac
}

# Only run if executed directly
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
