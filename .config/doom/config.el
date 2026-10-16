;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; No `doom sync' needed after editing this file; restart or `SPC h r r'.

;;; Look

(setq catppuccin-flavor 'mocha
      doom-theme 'catppuccin
      doom-font (font-spec :family "JetBrains Mono" :size 14)
      display-line-numbers-type t)

;;; Behaviour carried over from nvim

;; Space is Doom's leader already; use comma as localleader like nvim does
(setq doom-localleader-key ","
      doom-localleader-alt-key "M-,")

;; jk or kj leaves insert mode
(after! evil-escape
  (setq evil-escape-key-sequence "jk"
        evil-escape-unordered-key-sequence t))

;; j/k move by visual line on wrapped text (Doom already makes Y yank to eol)
(map! :nm "j" #'evil-next-visual-line
      :nm "k" #'evil-previous-visual-line)

;; Ctrl-h/j/k/l between windows, as with vim-tmux-navigator
(map! :n "C-h" #'evil-window-left
      :n "C-j" #'evil-window-down
      :n "C-k" #'evil-window-up
      :n "C-l" #'evil-window-right)

;; Notes live in ~/txt
(setq org-directory "~/txt/")

;;; Claude Code

(use-package! claude-code-ide
  :commands (claude-code-ide claude-code-ide-menu)
  :init
  (map! :leader
        (:prefix ("a" . "AI / Claude Code")
         :desc "Claude Code menu"   "a" #'claude-code-ide-menu
         :desc "Start/toggle"       "c" #'claude-code-ide
         :desc "Continue last"      "C" #'claude-code-ide-continue
         :desc "Resume session"     "r" #'claude-code-ide-resume
         :desc "Send prompt"        "s" #'claude-code-ide-send-prompt
         :desc "Insert selection"   "i" #'claude-code-ide-insert-at-mentioned
         :desc "Stop"               "q" #'claude-code-ide-stop
         :desc "List sessions"      "l" #'claude-code-ide-list-sessions))
  :config
  (setq claude-code-ide-terminal-backend 'ghostel)
  ;; Let Claude use xref, project, imenu and tree-sitter via MCP tools
  (claude-code-ide-emacs-tools-setup))

;;; GitHub PR review

(use-package! pr-review
  :commands (pr-review pr-review-open pr-review-search pr-review-notification)
  :init
  (map! :leader
        (:prefix ("g" . "git")
         (:prefix ("v" . "review PRs")
          :desc "Open PR by URL"     "v" #'pr-review
          :desc "Open PR at point"   "o" #'pr-review-open
          :desc "Search PRs"         "s" #'pr-review-search
          :desc "Review requests"    "n" #'pr-review-notification))))
