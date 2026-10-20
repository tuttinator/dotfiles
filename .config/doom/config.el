;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; No `doom sync' needed after editing this file; restart or `SPC h r r'.

;;; PATH

;; Emacs.app started from Finder doesn't see .zshrc, so add Homebrew and mise
;; shims (which pick each project's mise versions) for language servers etc.
(dolist (dir (list "/opt/homebrew/bin" (expand-file-name "~/.local/share/mise/shims")))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir path-separator (getenv "PATH")))))

;;; Look

;; Tomorrow Night everywhere (iTerm, nvim, bat, glow, starship) except tmux,
;; which is still Catppuccin; SPC h t switches themes
;; Font matches the iTerm Main profile; ligatures come from :ui ligatures
(setq doom-theme 'doom-tomorrow-night
      doom-font (font-spec :family "GeistMono Nerd Font Mono" :size 14)
      display-line-numbers-type t)

;;; Behaviour carried over from nvim

;; Space is Doom's leader already; use comma as localleader like nvim does
(setq doom-localleader-key ","
      doom-localleader-alt-key "M-,")

;; jk or kj leaves insert mode
(after! evil-escape
  (setq evil-escape-key-sequence "jk"
        evil-escape-unordered-key-sequence t))

;; Soft-wrap long lines everywhere (SPC t w toggles it per buffer). Read-only
;; "special" buffers such as pr-review are skipped; they opt in below.
(+global-word-wrap-mode +1)

;; j/k move by visual line on wrapped text (Doom already makes Y yank to eol)
(map! :nm "j" #'evil-next-visual-line
      :nm "k" #'evil-previous-visual-line)

;; Ctrl-h/j/k/l between windows, as with vim-tmux-navigator
(map! :n "C-h" #'evil-window-left
      :n "C-j" #'evil-window-down
      :n "C-k" #'evil-window-up
      :n "C-l" #'evil-window-right)

;;; Languages

;; Homebrew's elixir-ls is named `elixir-ls', not eglot's `language_server.sh'
(set-eglot-client! '(elixir-mode elixir-ts-mode heex-ts-mode) '("elixir-ls"))

;; TypeScript 7 dropped tsserver.js (so typescript-language-server can't use
;; it) and has its own `tsc --lsp'. Use the global tsc: Doom puts the
;; project's node_modules/.bin first, where an older tsc lacks --lsp.
(defun +typescript-lsp-contact (&rest _)
  (list (let ((exec-path (default-value 'exec-path))) (or (executable-find "tsc") "tsc"))
        "--lsp" "--stdio"))
(set-eglot-client! '((js-mode :language-id "javascript")
                     (js-ts-mode :language-id "javascript")
                     (tsx-ts-mode :language-id "typescriptreact")
                     (typescript-ts-mode :language-id "typescript")
                     (typescript-mode :language-id "typescript"))
                   #'+typescript-lsp-contact)

;; Doom's web module opens HTML in web-mode, which eglot has no server for
(set-eglot-client! 'web-mode '("vscode-html-language-server" "--stdio"))

;; Notes live in ~/txt
(setq org-directory "~/txt/")

;; Build missing tree-sitter grammars without asking. The y/n prompt otherwise
;; stalls pr-review halfway through rendering a diff.
(setq treesit-auto-install-grammar 'always)

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

;;; Codex, Gemini and friends (agent-shell over ACP)

;; Each agent logs in through its own CLI (codex login, gemini); agent-shell
;; reuses that. Codex runs through the codex-acp adapter from the Brewfile.
(use-package! agent-shell
  :commands (agent-shell agent-shell-openai-start-codex agent-shell-google-start-gemini)
  :init
  (map! :leader
        (:prefix "a"
         :desc "Codex"              "x" #'agent-shell-openai-start-codex
         :desc "Gemini"             "g" #'agent-shell-google-start-gemini
         :desc "Pick an agent"      "A" #'agent-shell))
  :config
  ;; agent-shell still defaults to the deprecated --experimental-acp
  (setq agent-shell-google-gemini-acp-command '("gemini" "--acp")))

;;; GitHub PR review

;; Forge and pr-review authenticate through ghub, which wants a token in
;; ~/.authinfo. Borrow the gh CLI's login instead (fetched once per session).
(defvar +ghub--gh-token nil)
(defadvice! +ghub--gh-cli-token-a (host &rest _)
  :before-until #'ghub--token
  (when (and (equal host "api.github.com") (executable-find "gh"))
    (or +ghub--gh-token
        (let ((token (string-trim (shell-command-to-string "gh auth token 2>/dev/null"))))
          (unless (string-empty-p token)
            (setq +ghub--gh-token token))))))

(use-package! pr-review
  :commands (pr-review pr-review-open pr-review-search pr-review-notification)
  :init
  (map! :leader
        (:prefix ("g" . "git")
         (:prefix ("v" . "review PRs")
          :desc "Open PR by URL"     "v" #'pr-review
          :desc "Open PR at point"   "o" #'pr-review-open
          :desc "Search PRs"         "s" #'pr-review-search
          :desc "Review requests"    "n" #'pr-review-notification)))
  :config
  (add-hook 'pr-review-mode-hook #'+word-wrap-mode)

  ;; pr-review fetches synchronously and stays silent until it's done, so say
  ;; what it's doing before each slow step (redisplay, or Emacs won't show it)
  (defun +pr-review--progress (fmt &rest args)
    (apply #'message fmt args)
    (redisplay t))
  (defun +pr-review--progress-fetch (&rest _)
    (apply #'+pr-review--progress "Fetching PR %s/%s/%s…" pr-review--pr-path))
  (defun +pr-review--progress-diff (&rest _)
    (+pr-review--progress "Fetching diff…"))
  (advice-add 'pr-review--fetch-pr-info :before #'+pr-review--progress-fetch)
  (advice-add 'pr-review--fetch-compare :before #'+pr-review--progress-diff)

  ;; Syntax-highlighting the diff is most of the load time (a 16k-line PR took
  ;; 15s of 18s), so skip it for big diffs
  (defvar +pr-review-syntax-line-limit 5000
    "Diffs with more lines than this are shown without syntax highlighting.")
  (defun +pr-review--render (orig pr diff &rest args)
    (let* ((lines (if (stringp diff) (cl-count ?\n diff) 0))
           (big (> lines +pr-review-syntax-line-limit))
           (pr-review-diff-font-lock-syntax
            (unless big pr-review-diff-font-lock-syntax)))
      (if big
          (+pr-review--progress "Rendering %d-line diff (no syntax highlighting)…" lines)
        (+pr-review--progress "Rendering…"))
      (apply orig pr diff args)))
  (advice-add 'pr-review--insert-pr :around #'+pr-review--render)

  ;; Claude Code in the local clone of the PR's repo, primed with the PR
  (defvar +pr-review-clone-roots '("~/Projects")
    "Where clones live, as ROOT/OWNER/REPO or ROOT/REPO.")

  (defun +pr-review--local-clone (owner repo)
    "Find a local clone of OWNER/REPO, or ask."
    (or (seq-find #'file-directory-p
                  (mapcan (lambda (root)
                            (list (expand-file-name (format "%s/%s" owner repo) root)
                                  (expand-file-name repo root)))
                          +pr-review-clone-roots))
        (seq-find
         (lambda (root)
           (and (string-equal-ignore-case
                 (file-name-nondirectory (directory-file-name root)) repo)
                (let ((default-directory root))
                  (string-match-p
                   (regexp-quote (format "%s/%s" owner repo))
                   (or (ignore-errors (car (process-lines "git" "remote" "get-url" "origin")))
                       "")))))
         (mapcar #'expand-file-name (projectile-relevant-known-projects)))
        (read-directory-name (format "Local clone of %s/%s: " owner repo))))

  (defun +pr-review--agent-prompt (owner repo number)
    "Opening message telling a coding agent which PR is under review."
    (format "I'm reviewing https://github.com/%s/%s/pull/%s. \
Read it with `gh pr view %s` and `gh pr diff %s`, then wait for my questions."
            owner repo number number number))

  (defvar claude-code-ide-cli-extra-flags)  ; let-bound below, so make it dynamic

  (defun +pr-review/claude ()
    "Start Claude Code in this PR's local clone, told which PR is under review."
    (interactive)
    (require 'claude-code-ide)
    (pcase-let* ((`(,owner ,repo ,number) pr-review--pr-path)
                 (default-directory (file-name-as-directory
                                     (+pr-review--local-clone owner repo)))
                 (prompt (+pr-review--agent-prompt owner repo number))
                 (claude-code-ide-cli-extra-flags
                  (string-trim (concat claude-code-ide-cli-extra-flags " "
                                       (shell-quote-argument prompt)))))
      (claude-code-ide)))

  (defun +pr-review/codex ()
    "Start Codex (agent-shell) in this PR's local clone, told which PR is under review."
    (interactive)
    (require 'agent-shell)
    (pcase-let* ((`(,owner ,repo ,number) pr-review--pr-path)
                 (dir (file-name-as-directory (+pr-review--local-clone owner repo)))
                 ;; Always a fresh session: an old one would be about another PR
                 (shell (agent-shell--start :config (agent-shell-openai-make-codex-config)
                                            :session-strategy 'new
                                            :cwd dir)))
      ;; Queued until the session is ready
      (agent-shell-insert :text (+pr-review--agent-prompt owner repo number)
                          :submit t :shell-buffer shell)))

  ;; GitHub-style "files changed" sidebar, grouped by directory

  ;; GitHub-style "files changed" sidebar, grouped by directory
  (set-popup-rule! "^\\*PR files" :side 'left :size 45 :select t :quit nil :ttl nil)

  (defvar-local +pr-review-files--review-buffer nil
    "The pr-review buffer this sidebar belongs to.")

  (define-derived-mode +pr-review-files-mode special-mode "PR files"
    "Sidebar listing the files changed in a pr-review buffer.")

  (defun +pr-review-files--jump (&optional keep-focus)
    "Jump to the diff of the file on this line; stay in the sidebar if KEEP-FOCUS."
    (interactive)
    (when-let* ((file (get-text-property (line-beginning-position) '+pr-review-file))
                (review +pr-review-files--review-buffer)
                (win (or (get-buffer-window review) (display-buffer review))))
      (with-selected-window win
        (pr-review-goto-file file)
        (recenter 0))
      (unless keep-focus (select-window win))))

  (defun +pr-review-files--preview ()
    "Show the file on this line without leaving the sidebar."
    (interactive)
    (+pr-review-files--jump t))

  (defun +pr-review/files-sidebar ()
    "Show the files changed in the current PR in a sidebar."
    (interactive)
    (unless (derived-mode-p 'pr-review-mode)
      (user-error "Not in a pr-review buffer"))
    (let ((review (current-buffer))
          (files (sort (delete-dups (pr-review--find-all-file-names)) #'string<))
          (buf (get-buffer-create
                (format "*PR files: %s*"
                        (string-remove-prefix "pr-review " (string-trim (buffer-name) "\\*" "\\*")))))
          last-dir)
      (with-current-buffer buf
        (+pr-review-files-mode)
        (setq +pr-review-files--review-buffer review)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (propertize (format "%d files changed\n" (length files))
                              'face 'magit-section-heading))
          (dolist (file files)
            (let ((dir (or (file-name-directory file) "./")))
              (unless (equal dir last-dir)
                (insert "\n" (nerd-icons-icon-for-dir dir) " "
                        (propertize dir 'face 'font-lock-comment-face) "\n")
                (setq last-dir dir))
              (insert (propertize (concat "  " (nerd-icons-icon-for-file file)
                                          " " (file-name-nondirectory file))
                                  '+pr-review-file file
                                  'mouse-face 'highlight)
                      "\n"))))
        (goto-char (point-min)))
      (pop-to-buffer buf)))

  (map! :map +pr-review-files-mode-map
        :n "RET"     #'+pr-review-files--jump
        :n "o"       #'+pr-review-files--preview
        :n "q"       #'quit-window
        :n "g r"     #'+pr-review/files-sidebar-refresh
        [mouse-1]    #'+pr-review-files--click)

  (defun +pr-review-files--click (event)
    "Jump to the file clicked on."
    (interactive "e")
    (mouse-set-point event)
    (+pr-review-files--jump))

  (defun +pr-review/files-sidebar-refresh ()
    "Rebuild the sidebar from its pr-review buffer."
    (interactive)
    (when-let ((review +pr-review-files--review-buffer))
      (with-current-buffer review (+pr-review/files-sidebar))))

  (map! :map pr-review-mode-map
        :localleader
        :desc "Files sidebar" "f" #'+pr-review/files-sidebar
        :desc "Go to file"    "g" #'pr-review-goto-file
        :desc "Ask Claude"    "c" #'+pr-review/claude
        :desc "Ask Codex"     "x" #'+pr-review/codex))

;; Let emacsclient (and the `prr' shell function) talk to this Emacs. Only the
;; first Emacs started gets the server; later ones skip it.
(add-hook! 'doom-after-init-hook
  (require 'server)
  (unless (or (daemonp) (server-running-p)) (server-start)))
