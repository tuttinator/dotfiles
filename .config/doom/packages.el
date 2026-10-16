;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; Packages beyond Doom's modules. Run `doom sync` after changing this.

;; Claude Code CLI inside Emacs, wired up over MCP (≈ claudecode.nvim).
;; Not on MELPA, so install from GitHub.
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

;; Matches nvim, tmux and the iTerm2 profile
(package! catppuccin-theme)

;; Line-by-line GitHub PR review (inline threads, approve/request changes)
(package! pr-review)
