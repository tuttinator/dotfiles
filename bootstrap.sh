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
    # Homebrew 7 refuses to load third-party tap formulae/casks until trusted
    brew tap d12frosted/emacs-plus
    brew trust --cask d12frosted/emacs-plus/emacs-plus-app
    for formula in derailed/k9s/k9s kenn-io/tap/roborev oven-sh/bun/bun stripe/stripe-cli/stripe; do
        brew tap "${formula%/*}"
        brew trust --formula "$formula"
    done
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

###############################################################################
# 3b. Install self-updating apps from their vendors' native installers
###############################################################################
# These apps ship their own updaters. A Homebrew-managed copy drifts out of
# sync with the self-updated app and `brew upgrade` then fails with "already
# an App", so we install them once from the vendor and let them update
# themselves. Each download must be signed by the vendor's Developer ID team.

# Forget an old cask without touching the app. `brew uninstall --cask` would
# delete the app from /Applications.
forget_cask() {
    local cask="$1"
    local caskroom
    caskroom="$(brew --caskroom)/$cask"
    if [[ -d "$caskroom" ]]; then
        log_info "Removing Homebrew's record of the $cask cask..."
        rm -rf "$caskroom"
    fi
}

# install_native_app <app name> <cask> <team id> <url>
# The URL may serve a .pkg, .dmg or .zip; the type is sniffed from the file.
install_native_app() {
    local name="$1" cask="$2" team="$3" url="$4"
    local tmp file kind mount app

    forget_cask "$cask"
    if [[ -d "/Applications/$name.app" ]]; then
        log_success "$name is already installed"
        return
    fi

    log_info "Installing $name from the vendor's installer..."
    tmp="$(mktemp -d)"
    file="$tmp/download"
    if ! curl -fsSL --retry 3 "$url" -o "$file"; then
        rm -rf "$tmp"
        log_error "$name download failed"
        return 1
    fi

    case "$(file -b "$file")" in
        xar\ archive*) kind=pkg ;;
        Zip\ archive*) kind=zip ;;
        *) kind=dmg ;;
    esac

    if [[ "$kind" == pkg ]]; then
        if [[ "$(pkgutil --check-signature "$file" 2>&1)" != *"($team)"* ]]; then
            rm -rf "$tmp"
            log_error "$name package signature could not be verified"
            return 1
        fi
        if ! sudo installer -pkg "$file" -target /; then
            rm -rf "$tmp"
            log_error "$name installation failed"
            return 1
        fi
        rm -rf "$tmp"
        log_success "$name installed (updates are managed by $name)"
        return
    fi

    if [[ "$kind" == zip ]]; then
        ditto -x -k "$file" "$tmp/x"
        app="$(find "$tmp/x" -maxdepth 2 -name '*.app' -print -quit)"
    else
        mount="$(hdiutil attach -nobrowse -readonly -noautoopen "$file" 2>/dev/null \
            | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
        app="$(find "$mount" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
    fi

    if [[ -z "$app" ]] \
        || ! codesign --verify --deep --strict "$app" 2>/dev/null \
        || [[ "$(codesign -dv "$app" 2>&1)" != *"TeamIdentifier=$team"* ]]; then
        [[ -n "$mount" ]] && hdiutil detach -quiet "$mount"
        rm -rf "$tmp"
        log_error "$name app signature could not be verified"
        return 1
    fi

    ditto "$app" "/Applications/$name.app"
    [[ -n "$mount" ]] && hdiutil detach -quiet "$mount"
    rm -rf "$tmp"
    log_success "$name installed (updates are managed by $name)"
}

case "$(uname -m)" in
    arm64) SLACK_ARCH="arm64"; ZOOM_ARCH="arm64"; FIGMA_ARCH="mac-arm"
           ORBSTACK_ARCH="arm64"; DBEAVER_ARCH="aarch64"; VLC_ARCH="arm64"
           ANDROID_STUDIO_ARCH="mac_arm" ;;
    *)     SLACK_ARCH="x64";   ZOOM_ARCH="x86";   FIGMA_ARCH="mac"
           ORBSTACK_ARCH="amd64"; DBEAVER_ARCH="x86_64"; VLC_ARCH="intel64"
           ANDROID_STUDIO_ARCH="mac" ;;
esac

# Claude's download page sits behind a bot check; its updater feed does not.
CLAUDE_URL="$(curl -fsSL https://downloads.claude.ai/releases/darwin/universal/RELEASES.json \
    | jq -r '.releases[-1].updateTo.url')"

# VLC has no "latest" link; its Sparkle feed lists releases oldest first.
VLC_URL="$(curl -fsSL "https://update.videolan.org/vlc/sparkle/vlc-$VLC_ARCH.xml" \
    | grep -o 'url="[^"]*\.dmg"' | tail -1 | cut -d'"' -f2 | sed 's|^http:|https:|')"

# Slack's PKG installs its privileged updater alongside the app.
install_native_app "Slack" slack BQR82RBBHL \
    "https://slack.com/api/desktop.latestRelease?arch=$SLACK_ARCH&redirect=1&variant=pkg"
install_native_app "Visual Studio Code" visual-studio-code UBF8T346G9 \
    "https://update.code.visualstudio.com/latest/darwin-universal/stable"
install_native_app "Claude" claude Q6L2SF6YDW "$CLAUDE_URL"
install_native_app "ChatGPT" chatgpt 2DC432GLL2 \
    "https://persistent.oaistatic.com/sidekick/public/ChatGPT.dmg"
install_native_app "Codex" codex-app 2DC432GLL2 \
    "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
install_native_app "Discord" discord 53Q6R32WPB \
    "https://discord.com/api/download?platform=osx"
install_native_app "zoom.us" zoom BJ4HAAB9B3 \
    "https://zoom.us/client/latest/zoomusInstallerFull.pkg?archType=$ZOOM_ARCH"
install_native_app "Figma" figma T8RA8NE3B7 \
    "https://desktop.figma.com/$FIGMA_ARCH/Figma.zip"
install_native_app "iTerm" iterm2 H7V7XYVQ7D \
    "https://iterm2.com/downloads/stable/latest"
install_native_app "Rectangle" rectangle XSYZ3E4B7D \
    "https://github.com/rxhanson/Rectangle/releases/latest/download/Rectangle.pkg"
install_native_app "OrbStack" orbstack HUAQ24HBR6 \
    "https://orbstack.dev/download/stable/latest/$ORBSTACK_ARCH"
install_native_app "DBeaver" dbeaver-community 42B6MDKMW8 \
    "https://dbeaver.io/files/dbeaver-ce-latest-macos-$DBEAVER_ARCH.dmg"
install_native_app "Tailscale" tailscale-app W5364U7YZB \
    "https://pkgs.tailscale.com/stable/Tailscale-latest-macos.pkg"
install_native_app "Cloudflare WARP" cloudflare-warp 68WVV388M8 \
    "https://downloads.cloudflareclient.com/v1/download/macos/ga"
install_native_app "Viscosity" viscosity 34XR7GXFPX \
    "https://www.sparklabs.com/downloads/Viscosity.dmg"
install_native_app "VLC" vlc 75GAHG3SZQ "$VLC_URL"

if [[ "$PROFILE" == full ]]; then
    POSITRON_URL="$(curl -fsSL https://cdn.posit.co/positron/releases/mac/universal/releases.json \
        | jq -r '.url')"
    # Android Studio's links carry the version, so take the current one from its page
    ANDROID_STUDIO_URL="$(curl -fsSL https://developer.android.com/studio \
        | grep -o "https://[^\"]*android-studio-[^\"]*-$ANDROID_STUDIO_ARCH\.dmg" | head -1)"

    install_native_app "Positron" positron FYF2F5GFX4 "$POSITRON_URL"
    install_native_app "Ollama" ollama-app 3MU9H2V9Y9 \
        "https://ollama.com/download/Ollama.dmg"
    install_native_app "Android Studio" android-studio EQHXZ8M8AV "$ANDROID_STUDIO_URL"
    # Only needed for bootstrap-pi-sd.sh --flash
    install_native_app "Raspberry Pi Imager" raspberry-pi-imager 8RDZTRXE62 \
        "https://downloads.raspberrypi.org/imager/imager_latest.dmg"
    # LM Studio only ships for Apple Silicon on macOS
    if [[ "$(uname -m)" == arm64 ]]; then
        install_native_app "LM Studio" lm-studio D65G88RHWN \
            "https://lmstudio.ai/download/latest/darwin/arm64"
    fi
fi

###############################################################################
# 3c. Install Codex CLI
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

# iTerm2 profiles. Main (Tomorrow Night, JetBrains Mono Nerd Font, Option as
# Meta) is the default; SSH inherits from it, and its automatic profile
# switching rules colour the tab whenever ssh/mosh is running or the shell
# reports a Tailscale host
ITERM_PROFILES="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$ITERM_PROFILES"
backup_and_link "$DOTFILES_DIR/iterm2/DynamicProfiles/main.json" "$ITERM_PROFILES/main.json"
backup_and_link "$DOTFILES_DIR/iterm2/DynamicProfiles/ssh.json" "$ITERM_PROFILES/ssh.json"
# iTerm writes its preferences back on quit, so only set the default while
# it's closed; otherwise pick Main under Settings > Profiles > Other Actions
ITERM_MAIN_GUID="$(jq -r '.Profiles[0].Guid' "$DOTFILES_DIR/iterm2/DynamicProfiles/main.json")"
if [[ "$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)" != "$ITERM_MAIN_GUID" ]]; then
    if ps -axo comm= | grep -q '/iTerm.app/Contents/MacOS/iTerm2$'; then
        log_warning "iTerm is running: set the Main profile as default in Settings > Profiles"
    else
        defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_MAIN_GUID"
        log_success "iTerm default profile set to Main"
    fi
fi
install_iterm2_shell_integration

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

# Doom Emacs: framework in ~/.config/emacs, config linked from dotfiles/.config/doom
if command -v emacs &> /dev/null; then
    if [[ ! -d "$HOME/.config/emacs" ]]; then
        log_info "Installing Doom Emacs..."
        git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"
        "$HOME/.config/emacs/bin/doom" install --force --no-config
        log_success "Doom Emacs installed"
    else
        "$HOME/.config/emacs/bin/doom" sync
    fi
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

# Setup Positron's terminal command. Positron's Command Palette performs the
# same app-bundle-to-PATH link interactively; using the existing user-local bin
# directory keeps bootstrap non-interactive, idempotent, and password-free.
log_info "Setting up Positron 'positron' command..."
POSITRON_CLI="/Applications/Positron.app/Contents/Resources/app/bin/code"
if [[ -x "$POSITRON_CLI" ]]; then
    if ! command -v positron &> /dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$POSITRON_CLI" "$HOME/.local/bin/positron"
        log_success "Positron 'positron' command installed"
    else
        log_success "Positron 'positron' command already available"
    fi
else
    log_warning "Positron not found in /Applications, skipping 'positron' command setup"
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
