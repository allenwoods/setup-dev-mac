#!/usr/bin/env bash
# 00-preflight.sh - System checks and prerequisites
# Verifies macOS version, architecture, and Xcode CLI tools

set -euo pipefail

MODULE_NAME="preflight"
MODULE_DESC="System checks and prerequisites"

run_module() {
    log_step "Running preflight checks"

    # Check macOS version
    check_macos_version

    # Check architecture
    check_architecture

    # Check/install Xcode CLI tools
    check_xcode_cli

    log_success "Preflight checks passed"
}

check_macos_version() {
    log_substep "Checking macOS version"

    local version
    version=$(get_macos_version)
    local major_version
    major_version=$(echo "$version" | cut -d. -f1)

    if [[ $major_version -lt 12 ]]; then
        log_error "macOS 12 (Monterey) or later is required. Found: $version"
        exit 1
    fi

    log_success "macOS $version"
}

check_architecture() {
    log_substep "Checking CPU architecture"

    local arch
    arch=$(get_architecture)

    case "$arch" in
        arm64)
            log_success "Apple Silicon (arm64)"
            ;;
        x86_64)
            log_success "Intel (x86_64)"
            if detect_rosetta; then
                log_warn "Running under Rosetta translation"
            fi
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

check_xcode_cli() {
    log_substep "Checking Xcode Command Line Tools"

    if detect_xcode_cli &>/dev/null; then
        log_success "Xcode CLI tools installed"
        return 0
    fi

    log_info "Xcode CLI tools not found, installing..."

    if is_dry_run; then
        log_info "[DRY-RUN] Would install Xcode CLI tools"
        return 0
    fi

    # Trigger the Xcode CLI tools installation prompt
    xcode-select --install 2>/dev/null || true

    # Wait for installation to complete
    echo ""
    echo "A dialog should appear asking to install Xcode Command Line Tools."
    echo "Please complete the installation, then press Enter to continue..."
    read -r

    # Verify installation
    if ! detect_xcode_cli &>/dev/null; then
        log_error "Xcode CLI tools installation failed or was cancelled"
        exit 1
    fi

    log_success "Xcode CLI tools installed"
}

# Only run if executed directly (not sourced for info)
if [[ "${1:-}" == "--run" ]]; then
    run_module
fi
