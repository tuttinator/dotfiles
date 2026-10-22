#!/bin/bash
###############################################################################
# Install or update Figwright (two-way Figma MCP server) from riez's fork,
# whose local/installed branch carries the Athena tools upstream doesn't have.
# Builds it in ~/Projects/figwright, registers it with Claude Code for every
# project and links its skills. Safe to re-run; it pulls and rebuilds.
#
# The Figma plugin still has to be imported by hand in the desktop app:
# Plugins → Development → Import plugin from manifest… and pick
# ~/Projects/figwright/packages/plugin/manifest.json
###############################################################################
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"

FIGWRIGHT_REPO="https://github.com/riez/figwright.git"
FIGWRIGHT_BRANCH="local/installed"
FIGWRIGHT_DIR="$HOME/Projects/figwright"

if [[ -d "$FIGWRIGHT_DIR/.git" ]]; then
    log_info "Updating Figwright in $FIGWRIGHT_DIR..."
    git -C "$FIGWRIGHT_DIR" fetch origin "$FIGWRIGHT_BRANCH"
    git -C "$FIGWRIGHT_DIR" checkout "$FIGWRIGHT_BRANCH"
    git -C "$FIGWRIGHT_DIR" merge --ff-only "origin/$FIGWRIGHT_BRANCH"
else
    log_info "Cloning Figwright into $FIGWRIGHT_DIR..."
    mkdir -p "$(dirname "$FIGWRIGHT_DIR")"
    git clone -b "$FIGWRIGHT_BRANCH" "$FIGWRIGHT_REPO" "$FIGWRIGHT_DIR"
fi

# The repo pins its pnpm through packageManager; mise's node brings corepack.
(
    cd "$FIGWRIGHT_DIR"
    pnpm install
    pnpm build
)
log_success "Figwright built"

claude mcp remove -s user figwright >/dev/null 2>&1 || true
claude mcp add -s user figwright -- node "$FIGWRIGHT_DIR/packages/mcp/dist/index.mjs"
log_success "Figwright registered with Claude Code"

mkdir -p "$HOME/.claude/skills"
for skill in figma-build figma-codegen; do
    ln -sfn "$FIGWRIGHT_DIR/skills/$skill" "$HOME/.claude/skills/$skill"
done
log_success "Figwright skills linked into ~/.claude/skills"

log_warning "Import the Figma plugin by hand: $FIGWRIGHT_DIR/packages/plugin/manifest.json"
