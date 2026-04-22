#!/bin/bash

###############################################################################
# Bootstrap Script for Raspberry Pi (Zero 2 W / Pi 5)
# Raspbian (Debian) – headless, accessed via SSH
# No desktop software, no Docker
###############################################################################

set -e

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DOTFILES_DIR/lib/common.sh"

# Detect Pi model
detect_pi_model() {
    local model
    model=$(cat /proc/cpuinfo 2>/dev/null | grep "Model" | head -1 | sed 's/.*: //')
    if echo "$model" | grep -qi "Pi 5"; then
        echo "pi5"
    elif echo "$model" | grep -qi "Zero 2"; then
        echo "zero2w"
    else
        echo "unknown"
    fi
}

PI_MODEL=$(detect_pi_model)
log_info "Dotfiles directory: $DOTFILES_DIR"
log_info "Detected Pi model: $PI_MODEL"

###############################################################################
# 1. System update and essential packages
###############################################################################
log_info "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

log_info "Installing essential packages..."
sudo apt-get install -y \
    build-essential \
    bat \
    btop \
    curl \
    fzf \
    git \
    git-lfs \
    gnupg \
    htop \
    jq \
    mosh \
    neovim \
    tmux \
    unzip \
    wget \
    zsh

log_success "Essential packages installed"

###############################################################################
# 1b. Install Tailscale
###############################################################################
log_info "Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    log_success "Tailscale installed — run 'sudo tailscale up --ssh' to join tailnet"
else
    log_success "Tailscale already installed"
fi

###############################################################################
# 2. Install Starship prompt
###############################################################################
log_info "Installing Starship prompt..."
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_success "Starship installed"
else
    log_success "Starship already installed"
fi

###############################################################################
# 3. Install mise (version manager)
###############################################################################
log_info "Installing mise..."
if ! command -v mise &> /dev/null; then
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    log_success "mise installed"
else
    log_success "mise already installed"
fi

###############################################################################
# 4. Install Node.js and Python via mise
###############################################################################
log_info "Setting up runtimes via mise..."
eval "$(mise activate bash)"

if [[ "$PI_MODEL" == "pi5" ]]; then
    mise use --global node@lts
    mise use --global python@latest
    log_success "Node.js LTS and Python installed via mise"

    if command -v npm &> /dev/null; then
        log_info "Installing Claude Code via npm..."
        npm install -g @anthropic-ai/claude-code
        log_success "Claude Code installed globally"
    fi
else
    mise use --global node@lts
    log_success "Node.js LTS installed via mise"
    log_warning "Skipping Claude Code on Pi Zero 2 W (limited resources)"
fi

###############################################################################
# 5. Install Antidote (zsh plugin manager)
###############################################################################
log_info "Installing Antidote..."
ANTIDOTE_HOME="${ZDOTDIR:-$HOME}/.antidote"
if [[ ! -d "$ANTIDOTE_HOME" ]]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_HOME"
    log_success "Antidote installed"
else
    log_success "Antidote already installed"
fi

###############################################################################
# 6. Create necessary directories
###############################################################################
log_info "Creating necessary directories..."
mkdir -p ~/.config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
log_success "Directories created"

###############################################################################
# 7. Symlink dotfiles (XDG layout)
###############################################################################
log_info "Creating symlinks for dotfiles..."

backup_and_link "$DOTFILES_DIR/zsh/.zshrc.linux" "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/zsh_plugins_linux.txt" "$HOME/.zsh_plugins.txt"

link_shared_dotfiles
cleanup_legacy_symlinks

###############################################################################
# 8. Setup Zsh plugins
###############################################################################
log_info "Installing Zsh plugins with Antidote..."
zsh -c "
    source '$ANTIDOTE_HOME/antidote.zsh'
    antidote install < '$DOTFILES_DIR/zsh/zsh_plugins_linux.txt'
    antidote bundle < '$DOTFILES_DIR/zsh/zsh_plugins_linux.txt'
" > ~/.zsh_plugins.sh
log_success "Zsh plugins configured"

###############################################################################
# 9. Install tmux plugin manager
###############################################################################
install_tpm_git

###############################################################################
# 10. Configure Git identity
###############################################################################
configure_git_identity

###############################################################################
# 11. Generate SSH Keys
###############################################################################
generate_ssh_key false

###############################################################################
# 12. Set default shell to zsh
###############################################################################
log_info "Setting default shell to zsh..."
if [[ "$SHELL" != */zsh ]]; then
    sudo chsh -s "$(which zsh)" "$USER"
    log_success "Default shell set to zsh (takes effect on next login)"
else
    log_success "Default shell is already zsh"
fi

###############################################################################
# 13. Setup fzf key bindings
###############################################################################
log_info "Setting up fzf..."
if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    cp /usr/share/doc/fzf/examples/key-bindings.zsh ~/.fzf.zsh
    if [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then
        cat /usr/share/doc/fzf/examples/completion.zsh >> ~/.fzf.zsh
    fi
    log_success "fzf key bindings configured"
else
    log_warning "fzf key bindings not found, skipping"
fi

###############################################################################
# Summary
###############################################################################
log_success "Bootstrap complete!"
echo ""
echo "Raspberry Pi ($PI_MODEL) setup completed!"
echo ""
echo "Next steps:"
echo "1. Log out and back in (for zsh shell change)"
echo "2. Add your SSH key to GitHub: https://github.com/settings/keys"
echo "3. Inside tmux, press prefix + I to install tmux plugins"
if [[ "$PI_MODEL" == "pi5" ]]; then
    echo "4. Set your ANTHROPIC_API_KEY environment variable for Claude Code"
fi
echo ""
