#!/usr/bin/env bash
# backup.sh - Backup utilities for setup-dev-mac
# Handles backing up existing configuration files before modifications

# Note: This file should be sourced after common.sh

# ============================================================================
# Configuration
# ============================================================================

# Default backup directory
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/.setup-dev-mac-backups}"

# Current session backup directory (set by init_backup_session)
BACKUP_SESSION_DIR=""

# ============================================================================
# Backup Session Management
# ============================================================================

# Initialize a backup session with timestamp
init_backup_session() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    BACKUP_SESSION_DIR="$BACKUP_BASE_DIR/$timestamp"

    if [[ "${SKIP_BACKUP:-false}" == "true" ]]; then
        log_info "Backup disabled (--skip-backup)"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would create backup directory: $BACKUP_SESSION_DIR"
        return 0
    fi

    ensure_dir "$BACKUP_SESSION_DIR"
    log_info "Backup session initialized: $BACKUP_SESSION_DIR"

    # Create a manifest file
    echo "# Backup Manifest - $timestamp" > "$BACKUP_SESSION_DIR/MANIFEST.txt"
    echo "# Created by setup-dev-mac" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"
    echo "" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"
}

# Get the current backup session directory
get_backup_dir() {
    echo "$BACKUP_SESSION_DIR"
}

# ============================================================================
# File Backup Functions
# ============================================================================

# Backup a single file
# Usage: backup_file /path/to/file [description]
backup_file() {
    local file="$1"
    local description="${2:-}"

    if [[ "${SKIP_BACKUP:-false}" == "true" ]]; then
        log_debug "Skipping backup for: $file"
        return 0
    fi

    if [[ ! -f "$file" ]]; then
        log_debug "File does not exist, nothing to backup: $file"
        return 0
    fi

    if [[ -z "$BACKUP_SESSION_DIR" ]]; then
        log_warn "Backup session not initialized, skipping backup for: $file"
        return 1
    fi

    # Create relative path structure in backup directory
    local relative_path="${file#$HOME/}"
    local backup_path="$BACKUP_SESSION_DIR/$relative_path"
    local backup_dir
    backup_dir=$(dirname "$backup_path")

    if is_dry_run; then
        log_info "[DRY-RUN] Would backup: $file -> $backup_path"
        return 0
    fi

    ensure_dir "$backup_dir"
    cp -p "$file" "$backup_path"

    # Add to manifest
    echo "$file -> $relative_path" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"
    [[ -n "$description" ]] && echo "  # $description" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"

    log_substep "Backed up: $file"
}

# Backup a directory
# Usage: backup_dir /path/to/dir [description]
backup_dir() {
    local dir="$1"
    local description="${2:-}"

    if [[ "${SKIP_BACKUP:-false}" == "true" ]]; then
        log_debug "Skipping backup for directory: $dir"
        return 0
    fi

    if [[ ! -d "$dir" ]]; then
        log_debug "Directory does not exist, nothing to backup: $dir"
        return 0
    fi

    if [[ -z "$BACKUP_SESSION_DIR" ]]; then
        log_warn "Backup session not initialized, skipping backup for: $dir"
        return 1
    fi

    # Create relative path structure in backup directory
    local relative_path="${dir#$HOME/}"
    local backup_path="$BACKUP_SESSION_DIR/$relative_path"
    local backup_parent
    backup_parent=$(dirname "$backup_path")

    if is_dry_run; then
        log_info "[DRY-RUN] Would backup directory: $dir -> $backup_path"
        return 0
    fi

    ensure_dir "$backup_parent"
    cp -Rp "$dir" "$backup_path"

    # Add to manifest
    echo "$dir/ -> $relative_path/" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"
    [[ -n "$description" ]] && echo "  # $description" >> "$BACKUP_SESSION_DIR/MANIFEST.txt"

    log_substep "Backed up directory: $dir"
}

# Backup multiple files matching a pattern
# Usage: backup_pattern "$HOME/.zsh*"
backup_pattern() {
    local pattern="$1"
    local description="${2:-}"

    # shellcheck disable=SC2086
    for file in $pattern; do
        if [[ -e "$file" ]]; then
            if [[ -d "$file" ]]; then
                backup_dir "$file" "$description"
            else
                backup_file "$file" "$description"
            fi
        fi
    done
}

# ============================================================================
# Restore Functions
# ============================================================================

# List available backup sessions
list_backups() {
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log_info "No backups found"
        return 1
    fi

    echo -e "\n${BOLD}Available Backups:${RESET}"
    local count=0
    for backup in "$BACKUP_BASE_DIR"/*/; do
        if [[ -d "$backup" ]]; then
            local name
            name=$(basename "$backup")
            local manifest="$backup/MANIFEST.txt"
            local file_count
            file_count=$(find "$backup" -type f ! -name "MANIFEST.txt" | wc -l | tr -d ' ')
            echo "  $name ($file_count files)"
            ((count++)) || true
        fi
    done

    if [[ $count -eq 0 ]]; then
        log_info "No backups found"
        return 1
    fi

    return 0
}

# Restore from a backup session
# Usage: restore_backup 20231215_143022
restore_backup() {
    local session="$1"
    local backup_path="$BACKUP_BASE_DIR/$session"

    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup session not found: $session"
        return 1
    fi

    log_step "Restoring from backup: $session"

    # Read manifest and restore files
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" || "$line" =~ ^[[:space:]]*#.*$ ]] && continue

        # Parse "original -> backup_relative" format
        if [[ "$line" =~ ^(.+)[[:space:]]+'->'[[:space:]]+(.+)$ ]]; then
            local original="${BASH_REMATCH[1]}"
            local backup_rel="${BASH_REMATCH[2]}"
            local backup_file="$backup_path/$backup_rel"

            if [[ -e "$backup_file" ]]; then
                if is_dry_run; then
                    log_info "[DRY-RUN] Would restore: $backup_file -> $original"
                else
                    # Ensure parent directory exists
                    local parent_dir
                    parent_dir=$(dirname "$original")
                    ensure_dir "$parent_dir"

                    cp -Rp "$backup_file" "$original"
                    log_substep "Restored: $original"
                fi
            fi
        fi
    done < "$backup_path/MANIFEST.txt"

    log_success "Restore complete"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

# Remove old backups, keeping the most recent N
# Usage: cleanup_old_backups [keep_count]
cleanup_old_backups() {
    local keep_count="${1:-5}"

    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        return 0
    fi

    local backups=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && backups+=("$line")
    done < <(ls -1d "$BACKUP_BASE_DIR"/*/ 2>/dev/null | sort -r)

    if [[ ${#backups[@]} -le $keep_count ]]; then
        log_debug "Only ${#backups[@]} backups exist, nothing to clean up"
        return 0
    fi

    log_info "Cleaning up old backups (keeping $keep_count most recent)"

    # Get backups to remove (after the first keep_count)
    local to_remove=()
    local i=0
    for backup in "${backups[@]}"; do
        if [[ $i -ge $keep_count ]]; then
            to_remove+=("$backup")
        fi
        ((i++))
    done
    for backup in "${to_remove[@]}"; do
        if is_dry_run; then
            log_info "[DRY-RUN] Would remove old backup: $backup"
        else
            rm -rf "$backup"
            log_substep "Removed: $(basename "$backup")"
        fi
    done
}

# Print backup summary
print_backup_summary() {
    if [[ "${SKIP_BACKUP:-false}" == "true" ]]; then
        log_info "Backups were disabled for this session"
        return 0
    fi

    if [[ -z "$BACKUP_SESSION_DIR" || ! -d "$BACKUP_SESSION_DIR" ]]; then
        log_info "No backups were created"
        return 0
    fi

    local file_count
    file_count=$(find "$BACKUP_SESSION_DIR" -type f ! -name "MANIFEST.txt" | wc -l | tr -d ' ')

    if [[ $file_count -gt 0 ]]; then
        log_info "Backed up $file_count file(s) to: $BACKUP_SESSION_DIR"
        echo -e "${DIM}To restore: ./install.sh --restore $(basename "$BACKUP_SESSION_DIR")${RESET}"
    else
        # Remove empty backup directory
        rmdir "$BACKUP_SESSION_DIR" 2>/dev/null || true
        log_debug "No files were backed up"
    fi
}
