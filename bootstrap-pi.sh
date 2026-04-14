#!/bin/bash

###############################################################################
# Bootstrap Script for Raspberry Pi (Zero 2 W / Pi 5)
# Raspbian (Debian) – headless, accessed via SSH
# No desktop software, no Docker
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

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

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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
    neovim \
    tmux \
    unzip \
    wget \
    zsh

log_success "Essential packages installed"

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

    # Install Claude Code on Pi 5 (enough resources to run it)
    if command -v npm &> /dev/null; then
        log_info "Installing Claude Code via npm..."
        npm install -g @anthropic-ai/claude-code
        log_success "Claude Code installed globally"
    fi
else
    # Pi Zero 2 W – Node LTS only, skip Claude Code (limited resources)
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
# 7. Symlink dotfiles
###############################################################################
log_info "Creating symlinks for dotfiles..."

backup_and_link() {
    local source_path="$1"
    local target_path="$2"

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

# Symlink Linux zshrc
backup_and_link "$DOTFILES_DIR/zsh/.zshrc.linux" "$HOME/.zshrc"

# Symlink Linux zsh plugins
backup_and_link "$DOTFILES_DIR/zsh/zsh_plugins_linux.txt" "$HOME/.zsh_plugins.txt"

# Symlink starship config
backup_and_link "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Symlink git config
backup_and_link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
backup_and_link "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

# Symlink tmux config
backup_and_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

# Symlink nvim config
if [[ -d "$DOTFILES_DIR/.config/nvim" ]]; then
    backup_and_link "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
fi

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
log_info "Installing tmux plugin manager..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    log_success "TPM installed (run prefix + I inside tmux to install plugins)"
else
    log_success "TPM already installed"
fi

###############################################################################
# 10. Configure Git (if not already configured)
###############################################################################
log_info "Configuring Git..."
if [[ -z "$(git config --global user.name)" ]]; then
    read -p "Enter your full name for Git: " git_name
    git config --global user.name "$git_name"
fi

if [[ -z "$(git config --global user.email)" ]]; then
    read -p "Enter your email for Git: " git_email
    git config --global user.email "$git_email"
fi

log_success "Git configured"

###############################################################################
# 11. Generate SSH Keys
###############################################################################
log_info "Setting up SSH keys..."
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
    read -p "Enter your email for SSH key: " ssh_email
    ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -N ""

    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519

    cat > ~/.ssh/config << EOF
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
EOF

    chmod 600 ~/.ssh/config

    log_success "SSH key generated"
    log_info "Your public key is:"
    cat ~/.ssh/id_ed25519.pub
    log_warning "Add this key to your GitHub account at https://github.com/settings/keys"
else
    log_success "SSH key already exists"
fi

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
