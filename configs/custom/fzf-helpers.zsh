# fzf helper functions
# Deployed to $ZSH_CUSTOM/fzf-helpers.zsh by mac-dev-setup

# fopen — fuzzy find files with Spotlight and open
# Usage: fopen [query]
#   fopen            → interactive: type to search
#   fopen 2026 docx  → pre-filtered: *2026*.docx
fopen() {
    local file
    if [[ -z "$1" ]]; then
        # Interactive mode: reload mdfind on every keystroke
        file=$(: | fzf --phw --bind "change:reload:mdfind \"kMDItemFSName == '*{q}*'\" 2>/dev/null || true" \
                       --preview 'ls -lh {}' \
                       --preview-window=down:1 \
                       --placeholder "Type to search files...") && open "$file"
    else
        local query="*${1}*"
        [[ -n "${2:-}" ]] && query="*${1}*.${2}"
        file=$(mdfind "kMDItemFSName == '$query'" | fzf) && open "$file"
    fi
}
