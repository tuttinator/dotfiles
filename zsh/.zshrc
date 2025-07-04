###############################################################################
#  Z-shell configuration – Starship for iTerm2
###############################################################################

# ── Colours ──────────────────────────────────────────────────────────────────
export COLORTERM=truecolor         # Advertise 24-bit colour to capable emulators

# ── Starship prompt ──────────────────────────────────────────────────────────
eval "$(starship init zsh)"

# ── History behaviour ────────────────────────────────────────────────────────
export HISTFILE=~/.zsh_history
setopt    appendhistory      # Keep adding to history file
setopt    sharehistory       # Share history across sessions
setopt    incappendhistory   # Sync immediately
setopt    HIST_IGNORE_ALL_DUPS

# ── Completion system ────────────────────────────────────────────────────────
autoload -Uz compinit
compinit

# ── Z-init / zsh-plugin-manager ──────────────────────────────────────────────
source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load

# ── Android SDK ──────────────────────────────────────────────────────────────
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/{emulator,tools,tools/bin,platform-tools}

# ── JavaScript / Bun / Yarn paths ────────────────────────────────────────────
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── Misc PATH additions ──────────────────────────────────────────────────────
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/bin:"* ]] && export PATH="$PATH:$HOME/bin"

# ── Misc env vars ────────────────────────────────────────────────────────────
COREPACK_ENABLE_AUTO_PIN=0

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/caleb/.lmstudio/bin"
# End of LM Studio CLI section

