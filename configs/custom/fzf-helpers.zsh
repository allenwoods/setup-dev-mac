# fzf helper functions
# Deployed to $ZSH_CUSTOM/fzf-helpers.zsh by mac-dev-setup

# fopen — fuzzy find files with Spotlight and open
# Usage: fopen <query>
# Example: fopen "2026 docx"  →  mdfind + fzf + open
fopen() {
    if [[ -z "$1" ]]; then
        echo "Usage: fopen <query>"
        echo "Example: fopen '2026 docx'"
        return 1
    fi
    local file
    file=$(mdfind "$*" | fzf) && open "$file"
}
