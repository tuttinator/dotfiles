# Cheat sheet

`cheat` shows this page; `cheat <word>` shows only matching lines.
Keep it in step with the config: it lives in dotfiles/cheatsheet.md.

## Shell keys

| Key | Does |
|---|---|
| `# describe it` then `⌥E` | AI turns the line into a command (aichat, gpt-6-luna) |
| `Tab` | Fuzzy completion with previews (fzf-tab); `,` `.` switch groups |
| `Ctrl-R` | Search history (atuin) |
| `↑` then `↑` | Last command, then all history newest first (atuin; Esc keeps the line) |
| `Ctrl-T` | Fuzzy-pick a file into the line (bat preview) |
| `⌥C` | Fuzzy cd into a subdirectory (eza tree preview) |
| `Esc Esc` | Put `sudo` in front of the line |
| `→` | Accept the grey autosuggestion |
| `⌥←` `⌥→` (iTerm SSH tabs) | Jump a word back or forward in the remote shell |

## Ask AI

| Command | Does |
|---|---|
| `llm cmd "undo last commit, keep changes"` | Drafts a command to edit before running |
| `llm "question"` | One-off question |
| `aichat` | Chat REPL |
| `claude` / `codex` / `agy` | Coding agents (`agy` is Antigravity) |
| `tldr tar` | Practical examples (offline, no AI) |

## Files and disk

| Command | Does |
|---|---|
| `ls` `ll` `la` `lt` | eza: list, long, all, tree |
| `z proj` | Jump to a frequent directory (zoxide) |
| `cat file` | bat with syntax highlighting |
| `fd name` / `rg text` | Find files / search contents |
| `sd 'old' 'new' file` | Find and replace, no regex escaping |
| `glow README.md` | Render Markdown, tables included |
| `chafa pic.jpg` | Show an image inline (works over ssh and in tmux) |
| `dust` | What's using disk, as a tree |
| `duf` | Drives and how full they are |
| `mo clean` | Clear caches and junk (mole) |

## Processes and timing

| Command | Does |
|---|---|
| `btop` | System monitor |
| `hyperfine 'cmd a' 'cmd b'` | Benchmark commands |
| `hyperfine 'zsh -i -c exit'` | Shell startup time |
| `watchexec -e lua -- cmd` | Re-run `cmd` when matching files change |

## Git

| Command | Does |
|---|---|
| `gst` `gd` `gaa` `gcmsg "msg"` | status, diff, add all, commit |
| `gco` `gcb name` `gsw` | checkout, new branch, switch |
| `gp` `gl` `glog` | push, pull, graph log |
| `git dft` | Syntax-aware diff (difftastic) |
| `git lol` / `git lola` | One-line graph (current / all branches) |
| `lazygit` | Git TUI (also tmux `` ` g ``) |
| `prr` / `prr 113` / `prr <url>` | Review a PR in Emacs |

## tmux (prefix is `` ` ``)

| Key | Does |
|---|---|
| `` ` T `` | Switch session (sesh) |
| `` ` g `` | lazygit popup |
| `` ` \| `` / `` ` t `` | Split right / below |
| `` ` h/j/k/l `` | Move between panes; `Ctrl-h/j/k/l` also crosses nvim splits |
| `` ` ←→↑↓ `` | Resize pane (repeatable) |
| `` ` r `` | Reload tmux config |

## Neovim (leader is Space)

| Key | Does |
|---|---|
| `␣pf` `␣pr` `␣pb` | Project files, recent, buffers |
| `␣sp` `␣sw` `␣s/` | Grep project, grep word, resume picker |
| `␣ft` `␣ff` | File tree, reveal current file |
| `␣gs` `␣gb` | Git status, blame (fugitive) |
| `]c` `[c` `␣hs` `␣hr` `␣hp` | Next/prev hunk, stage, reset, preview |
| `␣rn` `␣ca` `␣le` `␣lf` | Rename, code action, diagnostic, format |
| `␣ac` `␣as` `␣aa` `␣ad` | Claude: toggle, send, accept diff, deny diff |
| `␣<Tab>` | Previous buffer |

## Doom Emacs (leader is Space, local leader is `,`)

| Key | Does |
|---|---|
| `␣aa` `␣ac` `␣ar` | Claude Code menu, start, resume |
| `␣ax` `␣ag` `␣aA` | Codex, Antigravity, pick an agent |
| `␣gvv` `␣gvs` `␣gvn` | Open PR by URL, search PRs, review requests |
| `,f` `,c` `,x` (in a PR) | Files sidebar, ask Claude, ask Codex |

## This repo

| Command | Does |
|---|---|
| `mise run lint` / `mise run test` | Lint hooks / syntax checks |
| `mise run bootstrap` | Re-run machine setup |
| `mise run figwright` | Install or update Figwright (Figma MCP) for Claude Code |
| `brew bundle` | Install anything new in the Brewfile |
| `ac on` / `ac off` / `ac cool 22` | Pi: switch the A/C and confirm with the webcam (one resend if needed) |
| `ac status` / `ac calibrate` | Pi: on or off, from the camera / relearn where the unit is in frame |
| `irblaster coolix off` / `on` / `cool22` | Pi: send an A/C code without checking the camera |
| `ssh <pi> acsnap - \| chafa -` | Pi: show a webcam frame here (check the A/C responded) |
