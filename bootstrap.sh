#!/bin/bash

###############################################################################
# Bootstrap Script for macOS Dotfiles Setup
# Sets up a new Mac with dotfiles, homebrew, and essential tools
###############################################################################

set -e

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DOTFILES_DIR/lib/common.sh"

log_info "Dotfiles directory: $DOTFILES_DIR"

###############################################################################
# 1. Install / update Xcode Command Line Tools
#
# Some casks link against CLT headers; a pending CLT update makes
# `brew bundle` fail halfway through. We install or update before proceeding.
###############################################################################
log_info "Checking Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    xcode-select --install
    log_warning "Command Line Tools installation started in a GUI dialog."
    log_warning "Complete it, then re-run this script."
    exit 1
fi
log_success "Command Line Tools are installed"

log_info "Checking for pending Command Line Tools updates (this can take ~30s)..."
CLT_UPDATE=$(softwareupdate --list 2>/dev/null \
    | awk '/Label:.*Command Line Tools/ {sub(/^[[:space:]]*\*[[:space:]]*Label:[[:space:]]*/, ""); print; exit}')

if [[ -n "$CLT_UPDATE" ]]; then
    log_warning "Pending CLT update: $CLT_UPDATE"
    log_info "Installing (requires sudo)..."
    sudo softwareupdate --install "$CLT_UPDATE" --verbose
    log_success "Command Line Tools updated"
else
    log_success "Command Line Tools are up to date"
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
# Install profile: "minimal" (default) skips heavy toolchains; "full" installs
# everything. Override per-machine with DOTFILES_PROFILE=full ./bootstrap.sh
#
# The Brewfile reads HOMEBREW_DOTFILES_PROFILE, not DOTFILES_PROFILE — Homebrew
# strips non-HOMEBREW_ vars from the environment before evaluating the Brewfile,
# so an unprefixed var is silently ignored and you'd get "minimal" with no error.
PROFILE="${DOTFILES_PROFILE:-minimal}"
if [[ "$PROFILE" != "minimal" && "$PROFILE" != "full" ]]; then
    log_error "Unknown DOTFILES_PROFILE: $PROFILE (expected 'minimal' or 'full')"
    exit 1
fi
export HOMEBREW_DOTFILES_PROFILE="$PROFILE"

log_info "Installing packages from Brewfile (profile: $PROFILE)..."
if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    cd "$DOTFILES_DIR"
    brew bundle install --verbose
    log_success "Packages installed from Brewfile"
else
    log_error "Brewfile not found in $DOTFILES_DIR"
    exit 1
fi

# Install docker/tap/sbx separately — brew bundle fails to resolve it from the
# Brewfile. See https://docs.docker.com/ai/sandboxes/
if ! brew list sbx &> /dev/null && ! brew list --cask sbx &> /dev/null; then
    log_info "Installing sbx from docker/tap..."
    brew install docker/tap/sbx
    log_success "sbx installed"
else
    log_success "sbx already installed"
fi

# Install Slack from the official DMG rather than Homebrew so its built-in
# updater owns the app. A Homebrew-managed copy drifts out of sync with the
# self-updated app and `brew upgrade` then fails with "already an App".
SLACK_CASKROOM="$(brew --caskroom)/slack"
if [[ -d "$SLACK_CASKROOM" ]]; then
    # Migration: forget the old cask without touching /Applications/Slack.app
    # (`brew uninstall --cask slack` would delete the app).
    log_info "Removing Homebrew's record of the Slack cask..."
    rm -rf "$SLACK_CASKROOM"
    log_success "Slack is no longer managed by Homebrew"
fi

if [[ ! -d "/Applications/Slack.app" ]]; then
    log_info "Installing Slack from the official installer..."
    SLACK_TMP="$(mktemp -d)"
    curl -fsSL -o "$SLACK_TMP/Slack.dmg" "https://slack.com/ssb/download-osx-universal"
    hdiutil attach -nobrowse -quiet -mountpoint "$SLACK_TMP/mnt" "$SLACK_TMP/Slack.dmg"
    ditto "$SLACK_TMP/mnt/Slack.app" "/Applications/Slack.app"
    hdiutil detach -quiet "$SLACK_TMP/mnt"
    rm -rf "$SLACK_TMP"
    log_success "Slack installed (it keeps itself up to date)"
else
    log_success "Slack already installed"
fi

###############################################################################
# 3b. Install Codex CLI
###############################################################################
log_info "Installing Codex CLI from the official installer..."
if ! (set -o pipefail; curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh); then
    log_error "Codex CLI installation failed"
    exit 1
fi
log_success "Codex CLI installed"

###############################################################################
# 4. Create necessary directories
###############################################################################
log_info "Creating necessary directories..."
mkdir -p ~/.config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
log_success "Directories created"

###############################################################################
# 5. Symlink dotfiles (XDG layout)
###############################################################################
log_info "Creating symlinks for dotfiles..."

# macOS-specific zsh files
backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/zsh_plugins.txt" "$HOME/.zsh_plugins.txt"

# Shared (XDG) dotfiles
link_shared_dotfiles

# Rectangle config (macOS only)
if [[ -f "$DOTFILES_DIR/rectangle/RectangleConfig.json" ]]; then
    mkdir -p "$HOME/Library/Preferences"
    backup_and_link "$DOTFILES_DIR/rectangle/RectangleConfig.json" "$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
fi

# Migration: remove legacy home-dir symlinks now that XDG paths exist
cleanup_legacy_symlinks

###############################################################################
# 6. Setup Zsh plugins with Antidote
###############################################################################
log_info "Setting up Zsh plugins with Antidote..."

export PATH="$BREW_PREFIX/bin:$PATH"

ANTIDOTE_PATH="$BREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
if [[ -f "$ANTIDOTE_PATH" ]]; then
    log_success "Antidote found at $ANTIDOTE_PATH"
else
    log_error "Antidote not found at $ANTIDOTE_PATH"
    log_error "It should have been installed via Brewfile. Try running: brew install antidote"
    exit 1
fi

log_info "Installing and bundling Zsh plugins..."
zsh -c "
    source '$ANTIDOTE_PATH'
    antidote install < '$DOTFILES_DIR/zsh/zsh_plugins.txt'
    antidote bundle < '$DOTFILES_DIR/zsh/zsh_plugins.txt'
" > ~/.zsh_plugins.sh
log_success "Zsh plugins configured with Antidote"

###############################################################################
# 7. Configure Git identity (falls through if config already has user/email)
###############################################################################
configure_git_identity

###############################################################################
# 8. Generate SSH Keys
###############################################################################
generate_ssh_key true   # true = enable UseKeychain on macOS

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

brew services start postgresql@17
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

# Install Claude Code via the official native installer (auto-updates in the background)
log_info "Installing Claude Code via native installer..."
curl -fsSL https://claude.ai/install.sh | bash
log_success "Claude Code installed"

# Install the custom Claude Code status line script and register it + attribution
# defaults in ~/.claude/settings.json. Empty attribution strings strip the default
# "Co-Authored-By: Claude" / "Generated with Claude Code" trailers from commits/PRs,
# and sessionUrl=false drops the "Claude-Session:" trailer / PR-body link added by
# web and Remote Control sessions. Never put any attribution in here.
log_info "Configuring Claude Code status line and attribution..."
mkdir -p "$HOME/.claude"
install -m 0755 "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

python3 - <<'PY'
import json
import os

settings_path = os.path.expanduser("~/.claude/settings.json")
statusline_cmd = f"bash {os.path.expanduser('~/.claude/statusline-command.sh')}"

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

settings["statusLine"] = {"type": "command", "command": statusline_cmd}
settings["attribution"] = {"commit": "", "pr": "", "sessionUrl": False}

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY
log_success "Status line script installed and attribution defaults written"

# Configure Codex to suppress generated git commit attribution trailers.
# The CLI is installed above with the official Codex installer.
log_info "Configuring Codex git attribution..."
mkdir -p "$HOME/.codex"

python3 - <<'PY'
import os
import re

config_path = os.path.expanduser("~/.codex/config.toml")
setting = 'commit_attribution = ""'
assignment = re.compile(r"^\s*commit_attribution\s*=")
table = re.compile(r"^\s*\[")

if os.path.exists(config_path):
    with open(config_path) as f:
        lines = f.read().splitlines()
else:
    lines = []

first_table = next((i for i, line in enumerate(lines) if table.match(line)), len(lines))

for i in range(first_table):
    if assignment.match(lines[i]):
        lines[i] = setting
        break
else:
    if first_table < len(lines):
        lines[first_table:first_table] = [setting, ""]
    else:
        lines.append(setting)

with open(config_path, "w") as f:
    f.write("\n".join(lines))
    f.write("\n")
PY
log_success "Codex git attribution disabled"

# Setup VS Code 'code' command in PATH
log_info "Setting up VS Code 'code' command..."
if [[ -d "/Applications/Visual Studio Code.app" ]]; then
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
# 12. Final cleanup
###############################################################################
log_info "Performing final cleanup..."

killall Dock
killall Finder

log_success "Bootstrap complete!"

###############################################################################
# Summary
###############################################################################
echo ""
echo "🎉 Bootstrap completed successfully!"
echo ""
echo "Next steps:"
echo "1. Restart your terminal to load the new configuration"
echo "2. Inside tmux, press prefix + I to install tmux plugins"
echo "3. Add your SSH key to GitHub: https://github.com/settings/keys"
echo "4. Configure any application-specific settings, like aws cli, gcloud, etc."
echo ""
echo "Your dotfiles are now set up and ready to use!"
