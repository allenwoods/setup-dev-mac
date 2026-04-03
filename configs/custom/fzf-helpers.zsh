# fzf helper functions
# Deployed to $ZSH_CUSTOM/fzf-helpers.zsh by mac-dev-setup

# fopen — fuzzy find files by name with Spotlight and open
# Usage: fopen <keyword> [ext]
# Example: fopen 2026 docx  →  finds *2026*.docx
fopen() {
    if [[ -z "$1" ]]; then
        echo "Usage: fopen <keyword> [extension]"
        echo "  fopen 2026 docx    → *2026*.docx"
        echo "  fopen report       → *report*"
        return 1
    fi
    local query="*${1}*"
    [[ -n "${2:-}" ]] && query="*${1}*.${2}"
    local file
    file=$(mdfind "kMDItemFSName == '$query'" | fzf) && open "$file"
}
