;;; $DOOMDIR/init.el -*- lexical-binding: t; -*-

;; Which Doom modules are enabled. Run `doom sync` after changing this.
;; SPC h d h opens Doom's docs; K on a module name shows its documentation.

(doom! :completion
       (corfu +orderless)   ; in-buffer completion (≈ blink.cmp)
       vertico              ; minibuffer completion (≈ snacks picker)

       :ui
       doom
       dashboard
       hl-todo
       indent-guides
       modeline
       nav-flash
       ophints
       (popup +defaults)
       treemacs             ; SPC o p project drawer (≈ neo-tree)
       (vc-gutter +pretty)  ; ≈ gitsigns
       vi-tilde-fringe
       workspaces
       zen                  ; distraction-free writing for notes

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)     ; ≈ conform.nvim; skips formatters that aren't installed
       snippets
       (whitespace +guess +trim)
       word-wrap

       :emacs
       dired
       electric
       ibuffer
       tramp
       undo
       vc

       :term
       ghostel              ; terminal used by claude-code-ide.el

       :checkers
       syntax

       :tools
       direnv
       docker
       editorconfig
       (eval +overlay)
       llm                  ; gptel, for quick questions outside Claude Code
       lookup
       (lsp +eglot)         ; built-in eglot; servers come from brew/npm/mise
       (magit +forge)       ; Forge: PRs and issues inside Magit
       tree-sitter

       :os
       (:if (featurep :system 'macos) macos)

       :lang
       data
       (elixir +lsp +tree-sitter)
       emacs-lisp
       (go +lsp +tree-sitter)
       (javascript +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (lua +lsp +tree-sitter)
       markdown
       org
       (python +lsp +tree-sitter +uv)
       (ruby +lsp +tree-sitter)
       (rust +lsp +tree-sitter)
       (sh +lsp)
       (swift +lsp +tree-sitter)
       (web +lsp +tree-sitter)
       (yaml +lsp +tree-sitter)

       :config
       (default +bindings +smartparens))
