# AGENTS.md

Personal dotfiles for macOS (`bootstrap.sh`), Linux and Raspberry Pi
(`bootstrap-linux.sh`, `bootstrap-pi-sd.sh`) and DigitalOcean
(`bootstrap-digitalocean.sh`). See README.md for the layout.

## Keep cheatsheet.md up to date

`cheatsheet.md` is the one-page reference the `cheat` shell command shows.
When a change adds, removes or rebinds something the user types, update it in
the same commit:

- Shell keys, aliases and functions (`zsh/.zshrc`, plugins in `zsh/zsh_plugins.txt`)
- CLI tools added to or removed from the `Brewfile` that are run by hand
- Git aliases (`.config/git/config`)
- tmux bindings (`.config/tmux/tmux.conf`)
- Neovim leader mappings (`.config/nvim/lua`) and Doom bindings (`.config/doom/config.el`)
- `mise run` tasks (`mise.toml`)

Describe what the binding actually does in the config, not the tool's
defaults. Keep entries to one table row, under the existing section headings,
and drop rows for anything removed. Check with `cheat <word>`.

## Conventions

- Commits: conventional style (`feat(zsh): …`, `fix: …`), one topic per commit.
- Pre-commit hooks (lefthook) run shellcheck, shfmt (`-i 4 -ci`), stylua and
  gitleaks; `mise run lint` runs them on every file.
- macOS shells load the static plugin bundle `~/.zsh_plugins.sh`; after editing
  `zsh/zsh_plugins.txt`, rebuild it (bootstrap.sh shows how).
- Third-party Homebrew taps need `brew trust` before `brew bundle`; add new
  ones to the trust step in bootstrap.sh.
- Don't add zsh plugins that do work on every keypress or block the prompt on
  a daemon; check a new tab still opens quickly (`hyperfine 'zsh -i -c exit'`
  only covers startup, not the first prompt).
