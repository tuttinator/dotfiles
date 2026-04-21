-- Plugin specs for lazy.nvim. See :h lazy.nvim-lazy.nvim-plugin-spec
return {
  -- Theme -----------------------------------------------------------------
  {
    'nanotech/jellybeans.vim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.background = 'dark'
      vim.cmd.colorscheme('jellybeans')
    end,
  },

  -- Status line -----------------------------------------------------------
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    config = function()
      require('lualine').setup({
        options = {
          theme = 'jellybeans',
          icons_enabled = true,
          component_separators = { left = '', right = '' },
          section_separators   = { left = '', right = '' },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      })
    end,
  },

  -- Usability -------------------------------------------------------------
  { 'tpope/vim-commentary' },
  { 'tpope/vim-surround' },
  { 'tpope/vim-vinegar' },
  { 'tpope/vim-unimpaired' },

  -- File tree sidebar -----------------------------------------------------
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    keys = {
      { '<leader>ft', '<cmd>Neotree toggle<CR>',            desc = 'Toggle file tree' },
      { '<leader>ff', '<cmd>Neotree reveal<CR>',            desc = 'Reveal current file in tree' },
      { '<leader>fb', '<cmd>Neotree toggle source=buffers<CR>',      desc = 'Toggle buffer tree' },
      { '<leader>fg', '<cmd>Neotree toggle source=git_status<CR>',   desc = 'Toggle git status tree' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    config = function()
      require('neo-tree').setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = true,
          },
        },
        window = {
          width = 32,
          mappings = {
            ['<space>'] = 'none', -- don't swallow the leader key
          },
        },
      })
    end,
  },

  -- Lua helpers (dependency for gitsigns/lspconfig) -----------------------
  { 'nvim-lua/plenary.nvim', lazy = true },

  -- Fuzzy finder ----------------------------------------------------------
  {
    'junegunn/fzf',
    cond = vim.fn.has('win32') == 0,
    build = './install --all',
  },
  {
    'junegunn/fzf.vim',
    cond = vim.fn.has('win32') == 0,
    dependencies = { 'junegunn/fzf' },
  },
  {
    'ctrlpvim/ctrlp.vim',
    cond = vim.fn.has('win32') == 1,
  },

  -- Git -------------------------------------------------------------------
  { 'tpope/vim-fugitive', cmd = { 'Git', 'G' } },
  {
    'lewis6991/gitsigns.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('gitsigns').setup({
        signcolumn = true,
        numhl = false,
        linehl = false,
        current_line_blame = false,
        on_attach = function(bufnr)
          local gs = require('gitsigns')
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map('n', ']c', function() gs.next_hunk() end, 'Next git hunk')
          map('n', '[c', function() gs.prev_hunk() end, 'Prev git hunk')
          map('n', '<leader>hs', gs.stage_hunk,   'Stage hunk')
          map('n', '<leader>hr', gs.reset_hunk,   'Reset hunk')
          map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')
          map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
        end,
      })
    end,
  },

  -- LSP -------------------------------------------------------------------
  -- Enable language servers if their binaries are on PATH. No auto-install;
  -- use mise/brew/npm to provide the servers you need:
  --   npm i -g typescript typescript-language-server
  --   brew install gopls rust-analyzer lua-language-server pyright
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lspconfig = require('lspconfig')
      local servers = {
        ts_ls          = 'typescript-language-server',
        gopls          = 'gopls',
        rust_analyzer  = 'rust-analyzer',
        pyright        = 'pyright',
        lua_ls         = 'lua-language-server',
      }
      for server, binary in pairs(servers) do
        if vim.fn.executable(binary) == 1 then
          lspconfig[server].setup({})
        end
      end

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufnr = args.buf
          local function map(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map('gd',          vim.lsp.buf.definition,      'LSP: go to definition')
          map('gD',          vim.lsp.buf.declaration,     'LSP: go to declaration')
          map('gr',          vim.lsp.buf.references,      'LSP: find references')
          map('gi',          vim.lsp.buf.implementation,  'LSP: go to implementation')
          map('K',           vim.lsp.buf.hover,           'LSP: hover')
          map('<leader>rn',  vim.lsp.buf.rename,          'LSP: rename')
          map('<leader>ca',  vim.lsp.buf.code_action,     'LSP: code action')
          map('<leader>lf',  function() vim.lsp.buf.format({ async = true }) end, 'LSP: format')
          map('[d',          vim.diagnostic.goto_prev,    'Prev diagnostic')
          map(']d',          vim.diagnostic.goto_next,    'Next diagnostic')
          map('<leader>le',  vim.diagnostic.open_float,   'Show diagnostic')
        end,
      })

      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = '●' },
        severity_sort = true,
      })
    end,
  },

  -- GitHub Copilot (inline ghost-text completion) -------------------------
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = '<M-l>',       -- Alt-L to accept suggestion
            accept_word = '<M-w>',
            accept_line = '<M-j>',
            next = '<M-]>',
            prev = '<M-[>',
            dismiss = '<C-]>',
          },
        },
        panel = { enabled = false },
        filetypes = {
          markdown = true,
          gitcommit = true,
          yaml = true,
        },
      })
    end,
  },

  -- snacks.nvim (UI toolkit; used by avante for input/select) -------------
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      input = { enabled = true },
      picker = { enabled = true },
      notifier = { enabled = true },
    },
  },

  -- Avante.nvim (Cursor-style inline AI edits + chat) ---------------------
  -- Requires: cargo on PATH (for `make` build) and ANTHROPIC_API_KEY env var.
  -- Default keys: <leader>aa chat, <leader>ae edit, <leader>ar refresh.
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    version = false,
    build = 'make',
    opts = {
      provider = 'copilot',
      input = { provider = 'snacks' },
      selector = { provider = 'snacks' },
      providers = {
        copilot = {
          endpoint = 'https://api.githubcopilot.com',
          model = 'claude-sonnet-4',
          timeout = 30000,
          extra_request_body = {
            temperature = 0,
            max_tokens = 8192,
          },
        },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'folke/snacks.nvim',
      'nvim-tree/nvim-web-devicons',
      'zbirenbaum/copilot.lua',
    },
  },

  -- Markdown --------------------------------------------------------------
  { 'godlygeek/tabular', ft = 'markdown' },
  {
    'plasticboy/vim-markdown',
    ft = 'markdown',
    dependencies = { 'godlygeek/tabular' },
    init = function()
      vim.g.vim_markdown_folding_style_pythonic = 1
      vim.g.vim_markdown_toc_autofit = 1
    end,
  },
  { 'junegunn/vim-easy-align' },
}
