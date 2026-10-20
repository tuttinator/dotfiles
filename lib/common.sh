#!/bin/bash
###############################################################################
# Shared helpers for dotfiles bootstrap scripts.
# Caller must set `DOTFILES_DIR` before sourcing.
###############################################################################

# ── Colours & logging ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ── iTerm2 shell integration ─────────────────────────────────────────────────
# Reports host, directory and command marks to iTerm2, which its automatic
# profile switching relies on. The zshrc sources it, so only the script is
# fetched (the official installer would also append to ~/.zshrc).
install_iterm2_shell_integration() {
    log_info "Installing iTerm2 shell integration..."
    if curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"; then
        log_success "iTerm2 shell integration installed"
    else
        log_warning "Could not download iTerm2 shell integration, skipping"
    fi
}

# ── Symlink helper: backs up collisions, creates parent dirs ─────────────────
backup_and_link() {
    local source_path="$1"
    local target_path="$2"
    local target_dir
    target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    if [[ -e "$target_path" && ! -L "$target_path" ]]; then
        log_warning "Backing up existing $target_path to $target_path.backup"
        mv "$target_path" "$target_path.backup"
    fi

    if [[ -L "$target_path" ]]; then
        rm "$target_path"
    fi

    ln -sf "$source_path" "$target_path"
    log_success "Linked $source_path -> $target_path"
}

# ── Shared symlinks used by every platform (XDG layout) ──────────────────────
link_shared_dotfiles() {
    backup_and_link "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
    backup_and_link "$DOTFILES_DIR/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
    backup_and_link "$DOTFILES_DIR/.config/git/config" "$HOME/.config/git/config"
    backup_and_link "$DOTFILES_DIR/.config/git/ignore" "$HOME/.config/git/ignore"
    backup_and_link "$DOTFILES_DIR/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    backup_and_link "$DOTFILES_DIR/.default-npm-packages" "$HOME/.default-npm-packages"

    if [[ -d "$DOTFILES_DIR/.config/nvim" ]]; then
        backup_and_link "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
    fi

    # Doom Emacs user config ($DOOMDIR); Doom itself lives in ~/.config/emacs
    if [[ -d "$DOTFILES_DIR/.config/doom" ]]; then
        backup_and_link "$DOTFILES_DIR/.config/doom" "$HOME/.config/doom"
    fi

    if [[ -f "$DOTFILES_DIR/mole/whitelist" ]]; then
        backup_and_link "$DOTFILES_DIR/mole/whitelist" "$HOME/.config/mole/whitelist"
    fi

    # Tomorrow Night for bat and delta (git config's syntax-theme); bat only
    # sees custom themes after a cache rebuild. Debian names the binary batcat.
    backup_and_link "$DOTFILES_DIR/.config/bat/themes" "$HOME/.config/bat/themes"
    local bat_cmd
    for bat_cmd in bat batcat; do
        if command -v "$bat_cmd" &>/dev/null; then
            "$bat_cmd" cache --build >/dev/null
            break
        fi
    done

    # btop rewrites btop.conf on exit, so set only its theme rather than
    # linking the file. tomorrow-night ships with btop.
    local btop_conf="$HOME/.config/btop/btop.conf"
    mkdir -p "$(dirname "$btop_conf")"
    if grep -q '^color_theme' "$btop_conf" 2>/dev/null; then
        sed -i.bak 's/^color_theme = .*/color_theme = "tomorrow-night"/' "$btop_conf" && rm -f "$btop_conf.bak"
    else
        echo 'color_theme = "tomorrow-night"' >>"$btop_conf"
    fi
}

# ── Remove legacy home-directory symlinks once XDG paths are set up ─────────
cleanup_legacy_symlinks() {
    for link in "$HOME/.tmux.conf" "$HOME/.gitconfig" "$HOME/.gitignore_global"; do
        if [[ -L "$link" ]]; then
            rm "$link"
            log_info "Removed legacy symlink: $link"
        fi
    done
}

# ── Interactive git user.name / user.email (fallback for fresh machines) ────
configure_git_identity() {
    log_info "Configuring Git..."
    if [[ -z "$(git config --global user.name)" ]]; then
        read -r -p "Enter your full name for Git: " git_name
        git config --global user.name "$git_name"
    fi

    if [[ -z "$(git config --global user.email)" ]]; then
        read -r -p "Enter your email for Git: " git_email
        git config --global user.email "$git_email"
    fi

    log_success "Git configured"
}

# ── Generate ed25519 SSH key if missing ─────────────────────────────────────
# Pass "true" as first arg on macOS to add `UseKeychain yes` to ssh config.
# Skips entirely if any common key OR an ~/.ssh/config already exists — the
# function must never overwrite pre-existing SSH state.
generate_ssh_key() {
    local with_keychain="${1:-false}"
    log_info "Setting up SSH keys..."

    # Check for any common default key name — not just id_ed25519 — to avoid
    # generating a second key on a machine that already has one.
    local existing_keys=()
    for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_dsa"; do
        [[ -f "$key" ]] && existing_keys+=("$(basename "$key")")
    done

    if [[ ${#existing_keys[@]} -gt 0 ]]; then
        log_success "Existing SSH key(s) found, skipping key generation: ${existing_keys[*]}"
        return
    fi

    # If the user has an ssh config but no standard key, something non-trivial
    # is going on — bail rather than risk clobbering custom host entries.
    if [[ -f "$HOME/.ssh/config" ]]; then
        # shellcheck disable=SC2088 # literal ~/.ssh/config in user-facing text
        log_warning "~/.ssh/config exists but no standard key found; skipping to avoid overwriting your config"
        log_warning "Generate a key manually with: ssh-keygen -t ed25519 -C <email>"
        return
    fi

    read -r -p "Enter your email for SSH key: " ssh_email
    ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""

    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519"

    {
        echo "Host *"
        echo "    AddKeysToAgent yes"
        if [[ "$with_keychain" == "true" ]]; then
            echo "    UseKeychain yes"
        fi
        echo "    IdentityFile ~/.ssh/id_ed25519"
    } >"$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"

    log_success "SSH key generated"
    log_info "Your public key is:"
    cat "$HOME/.ssh/id_ed25519.pub"
    log_warning "Add this key to your GitHub account at https://github.com/settings/keys"

    if command -v pbcopy &>/dev/null; then
        pbcopy <"$HOME/.ssh/id_ed25519.pub"
        log_success "Public key copied to clipboard"
    fi
}

# ── Install TPM via git clone (for systems without brew-managed TPM) ────────
install_tpm_git() {
    log_info "Installing tmux plugin manager..."
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        log_success "TPM installed (run prefix + I inside tmux to install plugins)"
    else
        log_success "TPM already installed"
    fi
}
