# Dotfiles Migration to mac-dev-setup

**Date:** 2026-04-03
**Status:** Approved

## Summary

Migrate useful personal shell configurations from `~/dotfiles/` and `~/.zshrc` into the `mac-dev-setup` repo, remove all fig-related config, and establish a `$ZSH_CUSTOM` template system for personal/optional configurations.

## Background

- `~/dotfiles/` — old zplug-based dotfiles repo (allenwoods/dotfiles), outdated
- `~/.zshrc` — current active file with fig references and scattered PATH entries
- `~/fig-export/` — fig-managed plugin configs, fig is discontinued
- `mac-dev-setup` — modular Oh-My-Zsh-based setup repo (H2OSLabs/mac-dev-setup)

## Changes

### 1. zshrc.template modifications

File: `configs/zshrc.template`

Add to the user configuration section (after `source $ZSH/oh-my-zsh.sh`):

- `export LANG=en_US.UTF-8`
- vim/nvim aliases: `alias vi='nvim'`, `alias vim='nvim'`
- trash alias (macOS only): `alias rm="echo 'Moved to trash.'; trash"`
- atuin init: `eval "$(atuin init zsh)"`

### 2. Core tools addition

File: `modules/02-core-tools.sh`

Add to `CORE_FORMULAS` array:
- `atuin` — enhanced shell history with sync
- `trash` — safe rm replacement (macos-trash, Homebrew formula name: `trash`)

### 3. $ZSH_CUSTOM template system

New directory: `configs/custom/`

Oh-My-Zsh automatically sources all `*.zsh` files in `$ZSH_CUSTOM` (`~/.oh-my-zsh/custom/`). We leverage this for both shared and personal configs.

#### Shared configs (deployed directly as .zsh)

**`configs/custom/agents.zsh`** — AI coding agent aliases and env vars:
```bash
# Claude Code
alias cc='claude'
alias ccd='claude --permission-mode bypass'
export CLAUDE_CODE_NO_FLICKER=1

# Codex
alias cx='codex'
```

#### Personal configs (deployed as .template, interactive fill)

**`configs/custom/proxy.zsh.template`** — Proxy toggle functions:
```bash
# Proxy configuration
# Replace __PROXY_ADDR__ with your proxy address (e.g., 127.0.0.1:7897)

_set_proxy() {
    export ALL_PROXY="http://__PROXY_ADDR__"
    export HTTP_PROXY="$ALL_PROXY"
    export http_proxy="$ALL_PROXY"
    export HTTPS_PROXY="$ALL_PROXY"
    export https_proxy="$ALL_PROXY"
    echo "All proxy set to $ALL_PROXY"
}

_unset_proxy() {
    unset ALL_PROXY HTTP_PROXY http_proxy HTTPS_PROXY https_proxy
    echo "All proxy unset"
}

alias setproxy="_set_proxy"
alias unsetproxy="_unset_proxy"
```

**`configs/custom/homebrew-mirror.zsh.template`** — Homebrew mirror (optional, for users in China):
```bash
# Uncomment to use Tsinghua mirror for Homebrew
# export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
# export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
```

#### Deployment logic

In `modules/03-zsh-base.sh`, add a function to deploy `$ZSH_CUSTOM` templates:

1. Copy all `configs/custom/*.zsh` files directly to `$ZSH_CUSTOM/` (skip if exists, idempotent)
2. For each `configs/custom/*.zsh.template` file:
   - If corresponding `.zsh` already exists in `$ZSH_CUSTOM/`, skip
   - Detect placeholders (pattern: `__[A-Z_]+__`)
   - Prompt user interactively for each placeholder value
   - If user provides values, substitute and save as `.zsh`
   - If user skips, copy as `.zsh.template` (Oh-My-Zsh ignores non-.zsh files)
3. Dry-run mode: print what would be deployed without writing

### 4. IdeaVim configuration

New file: `configs/ideavimrc`

Simplified IdeaVim config, no external dependencies (no intellimacs):
- Basic settings: line numbers, search highlighting, incremental search, scroll offset
- System clipboard: `set clipboard+=unnamedplus`
- IdeaVim plugins: `set surround`, `set highlightedyank`
- Minimal keybindings: `Y` → `y$`, leader key basics

Deployed by `modules/03-zsh-base.sh` (or a new dedicated step) to `~/.ideavimrc`.

### 5. Cleanup (local machine, not in repo)

- Remove fig reference from `~/.zshrc`: the line sourcing `$HOME/fig-export/dotfiles/dotfile.zsh`
- Remove BW_SESSION from `~/dotfiles/.zshrc` (security cleanup)
- `~/fig-export/` directory can be deleted by user manually

## Out of scope

- conda init (mac-dev-setup uses uv, not conda)
- zplug configuration (replaced by Oh-My-Zsh)
- Powerlevel10k / .p10k.zsh (replaced by Oh-My-Posh)
- gitignore function `gi()` (not requested)
- Emacs PATH (not requested)
- Kiro CLI blocks in ~/.zshrc (auto-managed by Kiro, leave as-is)
- Windsurf/Antigravity PATH entries (tool-specific, leave as-is)

## File change summary

| Action | File | Description |
|--------|------|-------------|
| Modify | `configs/zshrc.template` | Add LANG, vim alias, trash alias, atuin |
| Modify | `modules/02-core-tools.sh` | Add atuin, trash to CORE_FORMULAS |
| Modify | `modules/03-zsh-base.sh` | Add $ZSH_CUSTOM template deployment |
| Create | `configs/custom/agents.zsh` | Claude/Codex aliases and env vars |
| Create | `configs/custom/proxy.zsh.template` | Proxy toggle functions |
| Create | `configs/custom/homebrew-mirror.zsh.template` | Optional Homebrew mirror |
| Create | `configs/ideavimrc` | Simplified IdeaVim config |
