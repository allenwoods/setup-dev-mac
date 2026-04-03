# Dotfiles Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate useful shell configs from ~/dotfiles/ into mac-dev-setup, establish $ZSH_CUSTOM template system, remove fig references.

**Architecture:** Extend existing modular install system. New config files in `configs/custom/` are deployed to `$ZSH_CUSTOM` by module 03. Template files (`.zsh.template`) use `__PLACEHOLDER__` patterns for interactive fill. Shared configs deploy as plain `.zsh`.

**Tech Stack:** Bash (3.x compatible), Oh-My-Zsh, Homebrew

---

### Task 1: Add atuin and trash to core tools

**Files:**
- Modify: `modules/02-core-tools.sh:11-18` (CORE_FORMULAS array)
- Modify: `modules/99-finalize.sh:35-57` (verify atuin)
- Modify: `lib/detect.sh` (add detect_atuin)

- [ ] **Step 1: Add formulas to CORE_FORMULAS**

In `modules/02-core-tools.sh`, change the CORE_FORMULAS array from:

```bash
CORE_FORMULAS=(
    "tmux"
    "fzf"
    "fzf-tab"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "oh-my-posh"
)
```

To:

```bash
CORE_FORMULAS=(
    "tmux"
    "fzf"
    "fzf-tab"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "oh-my-posh"
    "atuin"
    "trash"
)
```

- [ ] **Step 2: Add detect_atuin to detect.sh**

Add after `detect_uv` function (line 96) in `lib/detect.sh`:

```bash
detect_atuin() {
    if command_exists atuin; then
        atuin --version | awk '{print $2}'
        return 0
    fi
    return 1
}
```

- [ ] **Step 3: Add atuin to finalize verification**

In `modules/99-finalize.sh`, add after the fzf verification block (after line 51):

```bash
    if verify_tool "atuin" "atuin --version | awk '{print \$2}'"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
```

- [ ] **Step 4: Add atuin to detection summary**

In `lib/detect.sh`, in `print_detection_summary`, add `atuin` to the core tools loop (line 243):

Change:
```bash
    for tool in homebrew zsh tmux fzf; do
```
To:
```bash
    for tool in homebrew zsh tmux fzf atuin; do
```

- [ ] **Step 5: Commit**

```bash
git add modules/02-core-tools.sh lib/detect.sh modules/99-finalize.sh
git commit -m "feat: add atuin and trash to core tools"
```

---

### Task 2: Update zshrc.template with new configs

**Files:**
- Modify: `configs/zshrc.template:91-133`

- [ ] **Step 1: Add LANG, aliases, and atuin init**

In `configs/zshrc.template`, replace the user configuration section (lines 93-133) with:

```bash
# User configuration

# Language environment
export LANG=en_US.UTF-8

# Preferred editor
export EDITOR='nvim'

# Editor aliases
alias vi='nvim'
alias vim='nvim'

# Safe rm — move to trash instead of deleting (macOS only)
if [[ "$OSTYPE" == darwin* ]] && command -v trash &>/dev/null; then
    alias rm='trash'
fi

# Atuin — enhanced shell history
eval "$(atuin init zsh)"

# Oh My Posh configuration (di4am0nd theme)
eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/di4am0nd.omp.json)"

# fzf-tab plugin
source "/opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"

# zsh-autosuggestions (Homebrew)
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting (must be last)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

Note: The commented-out boilerplate (MANPATH, example aliases, etc.) is removed. The Oh-My-Posh and plugin source lines at the end remain unchanged.

- [ ] **Step 2: Commit**

```bash
git add configs/zshrc.template
git commit -m "feat: add LANG, nvim aliases, trash alias, atuin init to zshrc template"
```

---

### Task 3: Create $ZSH_CUSTOM config files

**Files:**
- Create: `configs/custom/agents.zsh`
- Create: `configs/custom/proxy.zsh.template`
- Create: `configs/custom/homebrew-mirror.zsh.template`

- [ ] **Step 1: Create configs/custom/ directory**

```bash
mkdir -p configs/custom
```

- [ ] **Step 2: Create agents.zsh**

Create `configs/custom/agents.zsh`:

```bash
# AI Coding Agents — aliases and environment
# Deployed to $ZSH_CUSTOM/agents.zsh by mac-dev-setup

# Claude Code
alias cc='claude'
alias ccd='claude --permission-mode bypass'
export CLAUDE_CODE_NO_FLICKER=1

# Codex
alias cx='codex'
```

- [ ] **Step 3: Create proxy.zsh.template**

Create `configs/custom/proxy.zsh.template`:

```bash
# Proxy configuration
# Deployed to $ZSH_CUSTOM/proxy.zsh by mac-dev-setup
#
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

- [ ] **Step 4: Create homebrew-mirror.zsh.template**

Create `configs/custom/homebrew-mirror.zsh.template`:

```bash
# Homebrew Mirror (for users in China)
# Deployed to $ZSH_CUSTOM/homebrew-mirror.zsh by mac-dev-setup
#
# Uncomment the lines below to use Tsinghua University mirror

# export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
# export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
```

- [ ] **Step 5: Commit**

```bash
git add configs/custom/
git commit -m "feat: add ZSH_CUSTOM config templates (agents, proxy, homebrew-mirror)"
```

---

### Task 4: Create simplified ideavimrc

**Files:**
- Create: `configs/ideavimrc`

- [ ] **Step 1: Create configs/ideavimrc**

Create `configs/ideavimrc`:

```vim
" Simplified IdeaVim configuration
" Deployed to ~/.ideavimrc by mac-dev-setup

" --- Basic settings ---
set number
set relativenumber
set scrolloff=5
set incsearch
set hlsearch
set ignorecase
set smartcase
set showmode

" --- System clipboard ---
set clipboard+=unnamedplus

" --- IdeaVim plugins ---
set surround
set highlightedyank

" --- Key mappings ---
" Y yanks to end of line (consistent with D, C)
nnoremap Y y$

" Clear search highlight
nnoremap <Esc> :nohlsearch<CR>
```

- [ ] **Step 2: Commit**

```bash
git add configs/ideavimrc
git commit -m "feat: add simplified ideavimrc config"
```

---

### Task 5: Add $ZSH_CUSTOM deployment logic to module 03

**Files:**
- Modify: `modules/03-zsh-base.sh:10-22` (run_module), append new functions

- [ ] **Step 1: Add deploy_custom_configs call to run_module**

In `modules/03-zsh-base.sh`, change `run_module` (lines 10-23) from:

```bash
run_module() {
    log_step "Setting up Oh-My-Zsh"

    # Check if zsh is the default shell
    check_default_shell

    # Install Oh-My-Zsh
    install_oh_my_zsh

    # Deploy standard zshrc template
    deploy_zshrc_template

    log_success "Oh-My-Zsh ready"
}
```

To:

```bash
run_module() {
    log_step "Setting up Oh-My-Zsh"

    # Check if zsh is the default shell
    check_default_shell

    # Install Oh-My-Zsh
    install_oh_my_zsh

    # Deploy standard zshrc template
    deploy_zshrc_template

    # Deploy $ZSH_CUSTOM config files
    deploy_custom_configs

    # Deploy ideavimrc
    deploy_ideavimrc

    log_success "Oh-My-Zsh ready"
}
```

- [ ] **Step 2: Add deploy_custom_configs function**

Add before the final `if [[ "${1:-}" == "--run" ]]` block in `modules/03-zsh-base.sh`:

```bash
deploy_custom_configs() {
    log_substep "Deploying \$ZSH_CUSTOM configs"

    local custom_dir="$HOME/.oh-my-zsh/custom"
    local configs_custom="$SCRIPT_DIR/configs/custom"

    if [[ ! -d "$configs_custom" ]]; then
        log_warn "configs/custom/ not found, skipping"
        return 0
    fi

    ensure_dir "$custom_dir"

    # Deploy shared configs (.zsh files) directly
    local f
    for f in "$configs_custom"/*.zsh; do
        [[ -f "$f" ]] || continue
        local basename
        basename=$(basename "$f")
        local dest="$custom_dir/$basename"

        if [[ -f "$dest" ]]; then
            log_debug "$basename already exists in \$ZSH_CUSTOM, skipping"
            continue
        fi

        if is_dry_run; then
            log_info "[DRY-RUN] Would deploy $basename to \$ZSH_CUSTOM/"
            continue
        fi

        cp "$f" "$dest"
        log_substep "Deployed $basename"
    done

    # Deploy template configs (.zsh.template files) with interactive fill
    for f in "$configs_custom"/*.zsh.template; do
        [[ -f "$f" ]] || continue
        local basename
        basename=$(basename "$f")
        local target_name="${basename%.template}"
        local dest="$custom_dir/$target_name"

        # Skip if already deployed (either as .zsh or .zsh.template)
        if [[ -f "$dest" ]] || [[ -f "$custom_dir/$basename" ]]; then
            log_debug "$target_name already exists in \$ZSH_CUSTOM, skipping"
            continue
        fi

        if is_dry_run; then
            log_info "[DRY-RUN] Would deploy $basename to \$ZSH_CUSTOM/"
            continue
        fi

        # Detect placeholders
        local placeholders
        placeholders=$(grep -oE '__[A-Z_]+__' "$f" | sort -u || true)

        if [[ -z "$placeholders" ]]; then
            # No placeholders, deploy directly as .zsh
            cp "$f" "$dest"
            log_substep "Deployed $target_name"
            continue
        fi

        # Interactive fill
        log_info "Configuring $target_name:"
        local content
        content=$(cat "$f")
        local all_filled=true

        for placeholder in $placeholders; do
            local var_name="${placeholder//__/}"
            local user_value=""
            read -rp "  Enter value for $var_name (or press Enter to skip): " user_value

            if [[ -n "$user_value" ]]; then
                content="${content//$placeholder/$user_value}"
            else
                all_filled=false
            fi
        done

        if [[ "$all_filled" == "true" ]]; then
            echo "$content" > "$dest"
            log_substep "Deployed $target_name (configured)"
        else
            # Save as .template so Oh-My-Zsh won't source it
            cp "$f" "$custom_dir/$basename"
            log_substep "Saved $basename (unconfigured — edit and rename to .zsh to activate)"
        fi
    done

    log_success "\$ZSH_CUSTOM configs deployed"
}

deploy_ideavimrc() {
    log_substep "Deploying ideavimrc"

    local src="$SCRIPT_DIR/configs/ideavimrc"
    local dest="$HOME/.ideavimrc"

    if [[ ! -f "$src" ]]; then
        log_debug "configs/ideavimrc not found, skipping"
        return 0
    fi

    if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
        log_success "ideavimrc already deployed"
        return 0
    fi

    if is_dry_run; then
        log_info "[DRY-RUN] Would deploy ideavimrc to $dest"
        return 0
    fi

    if [[ -f "$dest" ]]; then
        backup_file "$dest" "before deploying ideavimrc"
    fi

    cp "$src" "$dest"
    log_success "ideavimrc deployed"
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/03-zsh-base.sh
git commit -m "feat: add ZSH_CUSTOM template deployment and ideavimrc deploy to module 03"
```

---

### Task 6: Update CLAUDE.md documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update project structure in CLAUDE.md**

In `CLAUDE.md`, update the project structure tree to include the new files. Change the `configs/` section from:

```
├── configs/                   # Configuration templates
│   ├── zshrc.template         # Standard zshrc (single source of truth)
│   ├─��� tmux.conf.local.template
│   └── plugins.list
```

To:

```
├── configs/                   # Configuration templates
│   ├── zshrc.template         # Standard zshrc (single source of truth)
│   ├��─ tmux.conf.local.template
│   ├── plugins.list
│   ├── ideavimrc              # Simplified IdeaVim config
│   └── custom/                # $ZSH_CUSTOM templates
│       ├── agents.zsh         # Claude/Codex aliases (shared, deployed directly)
│       ├── proxy.zsh.template # Proxy config (personal, interactive fill)
��       └── homebrew-mirror.zsh.template  # Homebrew mirror (optional)
```

- [ ] **Step 2: Update module 03 description**

Change:
```
│   ├── 03-zsh-base.sh         # Oh-My-Zsh + zshrc template deploy
```
To:
```
│   ├── 03-zsh-base.sh         # Oh-My-Zsh + zshrc + $ZSH_CUSTOM deploy
```

- [ ] **Step 3: Update core-tools description**

Change:
```
│   ├── 02-core-tools.sh       # tmux, fzf, zsh plugins, oh-my-posh
```
To:
```
��   ├── 02-core-tools.sh       # tmux, fzf, zsh plugins, oh-my-posh, atuin
```

- [ ] **Step 4: Add "Add $ZSH_CUSTOM config" to Common Tasks**

Add after the "Add zsh plugins" section:

```markdown
### Add personal configuration (ZSH_CUSTOM)
- Shared configs: add `.zsh` file to `configs/custom/`, deployed directly
- Personal templates: add `.zsh.template` file with `__PLACEHOLDER__` patterns, users fill interactively
- Deploy with: `./install.sh --module=03-zsh-base`
```

- [ ] **Step 5: Add atuin to What's shared vs per-user table**

Add row:
```
| Atuin shell history | Per-user (`~/.local/share/atuin/`) | Synced via atuin account (optional) |
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with new configs, custom templates, atuin"
```

---

### Task 7: Clean up local ~/.zshrc (fig removal)

**Files:**
- Modify: `~/.zshrc` (local machine, not in repo)

- [ ] **Step 1: Remove fig reference from ~/.zshrc**

Remove this line from `~/.zshrc`:

```bash
[[ -f "$HOME/fig-export/dotfiles/dotfile.zsh" ]] && builtin source "$HOME/fig-export/dotfiles/dotfile.zsh"
```

- [ ] **Step 2: Remove BW_SESSION from ~/dotfiles/.zshrc**

Remove this line from `~/dotfiles/.zshrc`:

```bash
export BW_SESSION="<REDACTED>"
```

- [ ] **Step 3: Verify cleanup**

Run: `grep -n "fig-export\|fig_\|BW_SESSION" ~/.zshrc ~/dotfiles/.zshrc`
Expected: No matches
