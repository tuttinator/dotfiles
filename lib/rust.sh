#!/bin/bash
###############################################################################
# Install or update the Rust toolchain through rustup, on macOS and Linux.
#
# rustup, not Homebrew's `rust` formula: projects pin their toolchain in
# rust-toolchain.toml (athena-capture pins 1.99.1 plus wasm32), and only rustup
# reads that file, installs other targets (x86_64-apple-darwin for universal
# Mac builds) and gives every machine the same compiler.
#
# - macOS: Homebrew's `rustup` formula (in the Brewfile). It is keg-only, so
#   .zshrc puts $(brew --prefix)/opt/rustup/bin first on PATH. A leftover
#   `rust` or `rust-analyzer` formula is removed, so its cargo can't shadow the
#   rustup proxies.
# - Linux (WSL, Pi 5): the official installer into ~/.cargo, without touching
#   shell files (.zshrc.linux and .zshenv.linux already add ~/.cargo/bin).
#
# Then: the stable toolchain with rustfmt, clippy and rust-analyzer as the
# default, plus the Apple targets on macOS. Safe to re-run; it updates stable.
###############################################################################
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"

if [[ "$(uname -s)" == Darwin ]]; then
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew is required; run bootstrap.sh first"
        exit 1
    fi
    for formula in rust rust-analyzer; do
        if brew list --formula "$formula" &>/dev/null; then
            log_info "Removing Homebrew's $formula (rustup provides it)..."
            brew uninstall --formula "$formula" ||
                log_warning "Couldn't remove $formula (something depends on it); rustup still comes first on PATH"
        fi
    done
    brew list --formula rustup &>/dev/null || brew install rustup
    brew_prefix="$(brew --prefix)"
    export PATH="$brew_prefix/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
else
    if ! command -v rustup &>/dev/null && [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
        log_info "Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
            sh -s -- -y --no-modify-path --default-toolchain none --profile minimal
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
fi

log_info "Installing the stable toolchain..."
rustup toolchain install stable --profile minimal \
    --component rustfmt --component clippy --component rust-analyzer
rustup default stable >/dev/null

if [[ "$(uname -s)" == Darwin ]]; then
    # Universal Mac builds (athena-capture's apple/scripts/build-core.sh).
    rustup target add --toolchain stable aarch64-apple-darwin x86_64-apple-darwin
fi

log_success "Rust ready: $(rustup --version 2>/dev/null) · $(rustc --version)"
