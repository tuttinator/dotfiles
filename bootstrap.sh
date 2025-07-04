#!/bin/bash

###############################################################################
# Bootstrap Script for macOS Dotfiles Setup
# This script sets up a new Mac with dotfiles, homebrew, and essential tools
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
log_info "Dotfiles directory: $DOTFILES_DIR"

###############################################################################
# 1. Install Xcode Command Line Tools
###############################################################################
log_info "Installing Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    xcode-select --install
    log_warning "Please complete the Xcode Command Line Tools installation and run this script again."
    exit 1
else
    log_success "Xcode Command Line Tools already installed"
fi

###############################################################################
# 2. Install Homebrew
###############################################################################
log_info "Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installed successfully"
else
    log_success "Homebrew already installed"
fi

# Ensure Homebrew is in PATH for current session and future sessions
if [[ $(uname -m) == 'arm64' ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# Add to current session
eval "$($BREW_PREFIX/bin/brew shellenv)"

# Add to .zprofile if not already present
BREW_SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
if ! grep -q "$BREW_SHELLENV_LINE" ~/.zprofile 2>/dev/null; then
    echo "$BREW_SHELLENV_LINE" >> ~/.zprofile
    log_success "Added Homebrew to .zprofile"
else
    log_success "Homebrew already configured in .zprofile"
fi

###############################################################################
# 3. Install packages from Brewfile
###############################################################################
log_info "Installing packages from Brewfile..."
if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    cd "$DOTFILES_DIR"
    brew bundle install
    log_success "Packages installed from Brewfile"
else
    log_error "Brewfile not found in $DOTFILES_DIR"
    exit 1
fi

###############################################################################
# 4. Create necessary directories
###############################################################################
log_info "Creating necessary directories..."
mkdir -p ~/.config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
log_success "Directories created"

###############################################################################
# 5. Symlink dotfiles
###############################################################################
log_info "Creating symlinks for dotfiles..."

# Backup existing files if they exist
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

# Symlink .zshrc
backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

backup_and_link "$DOTFILES_DIR/zsh/zsh_plugins.txt" "$HOME/.zsh_plugins.txt"

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

# Symlink Rectangle config
if [[ -f "$DOTFILES_DIR/rectangle/RectangleConfig.json" ]]; then
    mkdir -p "$HOME/Library/Preferences"
    backup_and_link "$DOTFILES_DIR/rectangle/RectangleConfig.json" "$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
fi

###############################################################################
# 6. Setup Zsh plugins with Antidote
###############################################################################
log_info "Setting up Zsh plugins with Antidote..."

# Ensure Homebrew binaries are in PATH for current session
if [[ $(uname -m) == 'arm64' ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi
export PATH="$BREW_PREFIX/bin:$PATH"

# Source Antidote
ANTIDOTE_PATH="$BREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
if [[ -f "$ANTIDOTE_PATH" ]]; then
    log_success "Antidote found at $ANTIDOTE_PATH"
else
    log_error "Antidote not found at $ANTIDOTE_PATH"
    log_error "It should have been installed via Brewfile. Try running: brew install antidote"
    exit 1
fi

# Generate plugins using antidote in zsh context
log_info "Installing and bundling Zsh plugins..."
zsh -c "
    source '$ANTIDOTE_PATH'
    antidote install < '$DOTFILES_DIR/zsh/zsh_plugins.txt'
    antidote bundle < '$DOTFILES_DIR/zsh/zsh_plugins.txt'
" > ~/.zsh_plugins.sh
log_success "Zsh plugins configured with Antidote"

###############################################################################
# 7. Configure Git (if not already configured)
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
# 8. Generate SSH Keys
###############################################################################
log_info "Setting up SSH keys..."
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
    read -p "Enter your email for SSH key: " ssh_email
    ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -N ""

    # Start ssh-agent and add key
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519

    # Create SSH config
    cat > ~/.ssh/config << EOF
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOF

    chmod 600 ~/.ssh/config

    log_success "SSH key generated"
    log_info "Your public key is:"
    cat ~/.ssh/id_ed25519.pub
    log_warning "Please add this key to your GitHub account at https://github.com/settings/keys"

    # Copy to clipboard if pbcopy is available
    if command -v pbcopy &> /dev/null; then
        cat ~/.ssh/id_ed25519.pub | pbcopy
        log_success "Public key copied to clipboard"
    fi
else
    log_success "SSH key already exists"
fi

###############################################################################
# 9. Setup macOS defaults
###############################################################################
log_info "Configuring macOS defaults..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable .DS_Store on network drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Set dock to auto-hide
defaults write com.apple.dock autohide -bool false

# Set screenshot location to Desktop
defaults write com.apple.screencapture location -string "$HOME/Desktop"

# Disable automatic capitalization and correction
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

log_success "macOS defaults configured"

###############################################################################
# 10. Start essential services
###############################################################################
log_info "Starting essential services..."

# Start PostgreSQL
brew services start postgresql@17

# Start Redis
brew services start redis

log_success "Essential services started"

###############################################################################
# 11. Install additional tools and setup
###############################################################################
log_info "Setting up additional tools..."

# Setup mise (formerly rtx) for version management
if command -v mise &> /dev/null; then
    mise use --global node@lts
    mise use --global python@latest
    log_success "mise configured with Node.js and Python"
fi

# Setup fzf key bindings and fuzzy completion
if [[ -d /opt/homebrew/opt/fzf ]]; then
    /opt/homebrew/opt/fzf/install --all --no-bash --no-fish
elif [[ -d /usr/local/opt/fzf ]]; then
    /usr/local/opt/fzf/install --all --no-bash --no-fish
fi

# Install Claude Code globally via npm
if command -v npm &> /dev/null; then
    log_info "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code
    log_success "Claude Code installed globally"
else
    log_warning "npm not found, skipping Claude Code installation"
fi

# Setup VS Code 'code' command in PATH
log_info "Setting up VS Code 'code' command..."
if [[ -d "/Applications/Visual Studio Code.app" ]]; then
    # Create symlink for the code command if it doesn't exist
    if ! command -v code &> /dev/null; then
        sudo ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" /usr/local/bin/code
        log_success "VS Code 'code' command installed"
    else
        log_success "VS Code 'code' command already available"
    fi
else
    log_warning "Visual Studio Code not found in /Applications, skipping 'code' command setup"
fi

log_success "Additional tools configured"

###############################################################################
# 12. Final steps and cleanup
###############################################################################
log_info "Performing final cleanup..."

# Restart Dock and Finder to apply changes
killall Dock
killall Finder

# Source the new zsh configuration
if [[ "$SHELL" == */zsh ]]; then
    log_info "Reloading zsh configuration..."
    # Note: This won't work in the script context, user needs to restart terminal
fi

log_success "Bootstrap complete!"

###############################################################################
# Summary
###############################################################################
echo ""
echo "🎉 Bootstrap completed successfully!"
echo ""
echo "Next steps:"
echo "1. Restart your terminal to load the new configuration"
echo "2. Add your SSH key to GitHub: https://github.com/settings/keys"
echo "3. Install any additional apps from the Mac App Store"
echo "4. Configure any application-specific settings"
echo ""
echo "Your dotfiles are now set up and ready to use!"
