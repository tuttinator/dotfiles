#!/bin/bash

###############################################################################
# Bootstrap Script for Digital Ocean Ubuntu VMs
# Sets up a headless server for running Claude Code in Docker containers
###############################################################################

set -e

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DOTFILES_DIR/lib/common.sh"

log_info "Dotfiles directory: $DOTFILES_DIR"

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
    neovim \
    ssh \
    tmux \
    unzip \
    wget \
    zsh

log_success "Essential packages installed"

###############################################################################
# 2. Install Docker
###############################################################################
log_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER"
    log_success "Docker installed (log out and back in for group changes)"
else
    log_success "Docker already installed"
fi

###############################################################################
# 3. Install Starship prompt
###############################################################################
log_info "Installing Starship prompt..."
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_success "Starship installed"
else
    log_success "Starship already installed"
fi

###############################################################################
# 4. Install mise (version manager)
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
# 5. Install Node.js via mise and Claude Code
###############################################################################
log_info "Setting up Node.js and Claude Code..."
eval "$(mise activate bash)"
mise use --global node@lts
log_success "Node.js LTS installed via mise"

log_info "Installing Claude Code via native installer..."
curl -fsSL https://claude.ai/install.sh | bash
log_success "Claude Code installed"

###############################################################################
# 6. Install Antidote (zsh plugin manager)
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
# 7. Create necessary directories
###############################################################################
log_info "Creating necessary directories..."
mkdir -p ~/.config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
log_success "Directories created"

###############################################################################
# 8. Symlink dotfiles (XDG layout)
###############################################################################
log_info "Creating symlinks for dotfiles..."

backup_and_link "$DOTFILES_DIR/zsh/.zshrc.linux" "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/zsh_plugins_linux.txt" "$HOME/.zsh_plugins.txt"

link_shared_dotfiles
cleanup_legacy_symlinks

###############################################################################
# 9. Setup Zsh plugins
###############################################################################
log_info "Installing Zsh plugins with Antidote..."
zsh -c "
    source '$ANTIDOTE_HOME/antidote.zsh'
    antidote install < '$DOTFILES_DIR/zsh/zsh_plugins_linux.txt'
    antidote bundle < '$DOTFILES_DIR/zsh/zsh_plugins_linux.txt'
" > ~/.zsh_plugins.sh
log_success "Zsh plugins configured"

###############################################################################
# 10. Install tmux plugin manager
###############################################################################
install_tpm_git

###############################################################################
# 11. Configure Git identity
###############################################################################
configure_git_identity

###############################################################################
# 12. Generate SSH Keys
###############################################################################
generate_ssh_key false

###############################################################################
# 13. Set default shell to zsh
###############################################################################
log_info "Setting default shell to zsh..."
if [[ "$SHELL" != */zsh ]]; then
    sudo chsh -s "$(which zsh)" "$USER"
    log_success "Default shell set to zsh (takes effect on next login)"
else
    log_success "Default shell is already zsh"
fi

###############################################################################
# 14. Setup fzf key bindings
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
echo "Digital Ocean VM setup completed!"
echo ""
echo "Next steps:"
echo "1. Log out and back in (for docker group + zsh shell change)"
echo "2. Add your SSH key to GitHub: https://github.com/settings/keys"
echo "3. Inside tmux, press prefix + I to install tmux plugins"
echo "4. Set your ANTHROPIC_API_KEY environment variable for Claude Code"
echo ""
