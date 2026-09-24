cask_args appdir: '/Applications'

###############################################################################
# Install profile
#
# "minimal" (default) omits heavy toolchains that only earn their disk on a
# machine with room to spare. "full" installs everything.
#
# NOTE: Homebrew scrubs the environment before evaluating this file — only
# HOMEBREW_-prefixed vars survive. A plain DOTFILES_PROFILE is silently
# dropped and you get "minimal" with no error, so keep the prefix.
#
#   brew bundle install                                   # minimal
#   HOMEBREW_DOTFILES_PROFILE=full brew bundle install    # everything
###############################################################################
PROFILE = ENV.fetch("HOMEBREW_DOTFILES_PROFILE", "minimal")
full = PROFILE == "full"

tap "atlassian/homebrew-acli"
tap "aws/tap"
tap "derailed/k9s"
tap "kenn-io/tap"
tap "oven-sh/bun"
tap "pulumi/tap"
tap "stripe/stripe-cli"

brew "acli"
brew "antidote"
brew 'postgresql@17', link: true
brew "aws-iam-authenticator"
brew "awscli"
brew "biome"
brew "btop"
brew "cocoapods"
brew "dotnet"
brew "eksctl"
brew "erlang" if full      # erlang+elixir: mac-mini only
brew "elixir" if full
brew "fastlane"
brew "xcodegen"     # was installed but undeclared
brew "ffmpeg"
brew "fzf"
brew "fzy"
brew "helm"
brew "helmfile"     # was installed but undeclared
brew "temporal"

# Modern CLI tools
brew "atuin"        # magical shell history with SQLite backend + sync
brew "bat"          # cat with syntax highlighting
brew "direnv"       # per-directory env vars
brew "doppler"      # secrets manager CLI (moved from dopplerhq/cli tap to core)
brew "sops"         # encrypted secrets files (age/PGP/KMS)
brew "eza"          # modern ls replacement
brew "fd"           # fast, ergonomic find
brew "git-delta"    # better git diff viewer
brew "lazygit"      # TUI for git
brew "mas"          # Mac App Store CLI
brew "mole"         # `mo clean` — cache/junk cleaner (whitelist lives in dotfiles/mole/)
brew "ripgrep"      # fast grep (rg)
brew "zoxide"       # smart cd
brew "tree"
brew "htop"
brew "gh"

brew "git"
brew "git-filter-repo"
brew "git-lfs"
brew "gnu-sed"
brew "gnupg"
brew "go"
brew "graphviz"
brew "jq"
brew "yq"           # jq for YAML
brew "k6"
brew "mosh"
brew "opus"
brew "kubernetes-cli"
brew "kubectx"
brew "mise"
brew "neovim"
brew "nmap"
brew "node"
brew "pgvector"
brew "pipx"
brew "pnpm"
brew "r" if full      # r pulls gcc (~480MB) via openblas
brew "redis", restart_service: :changed
brew "rust" if full      # rust pulls llvm@22 (~1.5GB)
brew "solargraph"
brew "ssh-copy-id"
brew "starship"
brew "tmux"
brew "tpm"
brew "unzip"
brew "uv"
brew "websocat"
brew "wget"
brew "yarn"
brew "yt-dlp"

# Terminal recording / content creation
brew "asciinema"    # record terminal sessions as .cast (embeddable, text-based)
brew "vhs"          # scriptable terminal recordings -> GIF/MP4/WEBM

# Taps
brew "derailed/k9s/k9s"
brew "oven-sh/bun/bun"
brew "stripe/stripe-cli/stripe"
brew "kenn-io/tap/roborev"
# docker/tap/sbx is installed separately in bootstrap.sh via
# `brew install docker/tap/sbx` (see https://docs.docker.com/ai/sandboxes/).
# brew bundle's stricter formula/cask split refuses to resolve it here.

# Casks
cask "android-platform-tools"
cask "android-studio" if full   # ~2.5GB
cask "brewservicesmenubar"
cask "bruno"
cask "chatgpt"
cask "claude"
cask "cloudflare-warp"
cask "codex-app"
cask "dbeaver-community"
cask "figma"
cask "font-hack-nerd-font"
cask "font-jetbrains-mono"
cask "font-newsreader"
cask "gcloud-cli"
cask "iterm2"
cask "ngrok"
cask "orbstack"
cask "rectangle"
cask "rstudio" if full   # ~1.7GB
# slack is installed separately in bootstrap.sh from the official DMG so it
# self-updates; a Homebrew-managed copy fights the built-in updater.
cask "tailscale-app"
cask "vlc"
cask "visual-studio-code"
cask "discord"
cask "ollama-app" if full   # ~600MB
cask "viscosity"
cask "zoom"
cask "lm-studio" if full   # ~1.6GB
cask "cursor"
cask "raspberry-pi-imager"
