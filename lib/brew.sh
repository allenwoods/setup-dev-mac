#!/usr/bin/env bash
# brew.sh - Homebrew helper functions
# Provides utilities for installing and managing Homebrew packages

# Note: This file should be sourced after common.sh

# ============================================================================
# Homebrew Path Setup
# ============================================================================

# Ensure Homebrew is in PATH
setup_brew_path() {
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [[ -x "$brew_prefix/bin/brew" ]]; then
        eval "$("$brew_prefix/bin/brew" shellenv)"
        return 0
    fi
    return 1
}

# ============================================================================
# Installation Functions
# ============================================================================

# Install Homebrew if not present
install_homebrew() {
    if command_exists brew; then
        log_success "Homebrew already installed"
        return 0
    fi

    log_step "Installing Homebrew"

    if is_dry_run; then
        log_info "[DRY-RUN] Would install Homebrew"
        return 0
    fi

    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Setup PATH for current session
    setup_brew_path

    log_success "Homebrew installed"
}

# Update Homebrew
update_homebrew() {
    if ! command_exists brew; then
        log_error "Homebrew not installed"
        return 1
    fi

    log_substep "Updating Homebrew..."

    if is_dry_run; then
        log_info "[DRY-RUN] Would run: brew update"
        return 0
    fi

    brew update
}

# ============================================================================
# Package Management
# ============================================================================

# Check if a formula is installed
brew_is_installed() {
    local formula="$1"
    brew list --formula "$formula" &>/dev/null
}

# Check if a cask is installed
brew_cask_is_installed() {
    local cask="$1"
    brew list --cask "$cask" &>/dev/null
}

# Get installed version of a formula
brew_get_version() {
    local formula="$1"
    if brew_is_installed "$formula"; then
        brew list --versions "$formula" | awk '{print $2}'
    fi
}

# Install a formula if not present
# Usage: brew_install formula [tap]
brew_install() {
    local formula="$1"
    local tap="${2:-}"

    # Tap if specified
    if [[ -n "$tap" ]] && ! brew tap | grep -q "^$tap$"; then
        log_substep "Tapping $tap"
        if ! is_dry_run; then
            brew tap "$tap"
        fi
    fi

    if brew_is_installed "$formula"; then
        local version
        version=$(brew_get_version "$formula")
        log_success "$formula already installed ($version)"
        return 0
    fi

    log_substep "Installing $formula"

    if is_dry_run; then
        log_info "[DRY-RUN] Would run: brew install $formula"
        return 0
    fi

    brew install "$formula"
    log_success "$formula installed"
}

# Install a cask if not present
# Usage: brew_install_cask cask
brew_install_cask() {
    local cask="$1"

    if brew_cask_is_installed "$cask"; then
        log_success "$cask already installed"
        return 0
    fi

    log_substep "Installing $cask (cask)"

    if is_dry_run; then
        log_info "[DRY-RUN] Would run: brew install --cask $cask"
        return 0
    fi

    brew install --cask "$cask"
    log_success "$cask installed"
}

# Install multiple formulas
# Usage: brew_install_batch formula1 formula2 ...
brew_install_batch() {
    local formulas=("$@")
    local to_install=()

    # Check which formulas need to be installed
    for formula in "${formulas[@]}"; do
        if ! brew_is_installed "$formula"; then
            to_install+=("$formula")
        else
            local version
            version=$(brew_get_version "$formula")
            log_success "$formula already installed ($version)"
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_debug "All formulas already installed"
        return 0
    fi

    log_substep "Installing: ${to_install[*]}"

    if is_dry_run; then
        log_info "[DRY-RUN] Would run: brew install ${to_install[*]}"
        return 0
    fi

    brew install "${to_install[@]}"

    for formula in "${to_install[@]}"; do
        log_success "$formula installed"
    done
}

# ============================================================================
# Upgrade Functions
# ============================================================================

# Upgrade a formula if outdated
brew_upgrade_if_outdated() {
    local formula="$1"

    if ! brew_is_installed "$formula"; then
        log_warn "$formula not installed"
        return 1
    fi

    if brew outdated "$formula" &>/dev/null; then
        log_substep "Upgrading $formula"

        if is_dry_run; then
            log_info "[DRY-RUN] Would run: brew upgrade $formula"
            return 0
        fi

        brew upgrade "$formula"
        log_success "$formula upgraded"
    else
        log_debug "$formula is up to date"
    fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

# Clean up old versions and cache
brew_cleanup() {
    log_substep "Cleaning up Homebrew"

    if is_dry_run; then
        log_info "[DRY-RUN] Would run: brew cleanup"
        return 0
    fi

    brew cleanup
}

# ============================================================================
# Font Installation (via casks)
# ============================================================================

# Install a Nerd Font
# Usage: brew_install_nerd_font "Hack" -> installs font-hack-nerd-font
brew_install_nerd_font() {
    local font_name="$1"
    local cask_name="font-$(echo "$font_name" | tr '[:upper:]' '[:lower:]')-nerd-font"

    # Ensure homebrew/cask-fonts is tapped
    if ! brew tap | grep -q "^homebrew/cask-fonts$"; then
        log_substep "Tapping homebrew/cask-fonts"
        if ! is_dry_run; then
            brew tap homebrew/cask-fonts
        fi
    fi

    brew_install_cask "$cask_name"
}

# ============================================================================
# Info Functions
# ============================================================================

# Print Homebrew info
brew_print_info() {
    if ! command_exists brew; then
        log_error "Homebrew not installed"
        return 1
    fi

    local prefix
    prefix=$(brew --prefix)
    local version
    version=$(brew --version | head -n1)
    local formula_count
    formula_count=$(brew list --formula | wc -l | tr -d ' ')
    local cask_count
    cask_count=$(brew list --cask | wc -l | tr -d ' ')

    echo -e "\n${BOLD}Homebrew Info:${RESET}"
    echo "  Version:  $version"
    echo "  Prefix:   $prefix"
    echo "  Formulas: $formula_count installed"
    echo "  Casks:    $cask_count installed"
}
