-- Servers are enabled only if their binary is on PATH. No auto-install;
-- provide them with mise/brew/npm, e.g.
--   npm i -g typescript typescript-language-server pyright
--   brew install gopls rust-analyzer lua-language-server
local servers = {
  ts_ls = 'typescript-language-server',
  gopls = 'gopls',
  rust_analyzer = 'rust-analyzer',
  pyright = 'pyright-langserver',
  lua_ls = 'lua-language-server',
}

return {
  -- Completion menu (LSP, paths, snippets, buffer words).
  -- Copilot ghost text stays separate; see plugins/ai.lua.
  {
    'saghen/blink.cmp',
    version = '1.*', -- release tags ship a prebuilt fuzzy-matcher binary
    event = { 'InsertEnter', 'CmdlineEnter' },
    opts = {
      keymap = { preset = 'default' }, -- <C-y> accept, <C-n>/<C-p> select, <C-space> open
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
      },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      signature = { enabled = true },
    },
  },

  -- Provides server definitions in lsp/*.lua; we only call vim.lsp.enable.
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'saghen/blink.cmp' },
    config = function()
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })
      vim.lsp.config('lua_ls', {
        settings = { Lua = { diagnostics = { globals = { 'vim', 'Snacks' } } } },
      })

      for server, binary in pairs(servers) do
        if vim.fn.executable(binary) == 1 then
          vim.lsp.enable(server)
        end
      end
    end,
  },

  -- Formatting. Format-on-save is on by default; <leader>tf toggles it.
  -- Formatters are skipped if not installed; LSP formatting is the fallback.
  {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    keys = {
      {
        '<leader>lf',
        function()
          require('conform').format({ async = true })
        end,
        mode = { 'n', 'x' },
        desc = 'Format',
      },
      {
        '<leader>tf',
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify('Format on save ' .. (vim.g.disable_autoformat and 'off' or 'on'))
        end,
        desc = 'Toggle format on save',
      },
    },
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format' },
        go = { 'goimports', 'gofmt', stop_after_first = true },
        rust = { 'rustfmt' },
        javascript = { 'biome', 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'biome', 'prettierd', 'prettier', stop_after_first = true },
        javascriptreact = { 'biome', 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'biome', 'prettierd', 'prettier', stop_after_first = true },
        json = { 'biome', 'prettierd', 'prettier', stop_after_first = true },
        elixir = { 'mix' },
        sh = { 'shfmt' },
      },
      default_format_opts = { lsp_format = 'fallback' },
      format_on_save = function()
        if vim.g.disable_autoformat then
          return
        end
        return { timeout_ms = 1000 }
      end,
    },
  },

  -- Linters that aren't language servers. Only runs those that are installed.
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufWritePost' },
    config = function()
      local lint = require('lint')
      lint.linters_by_ft = {
        sh = { 'shellcheck' },
        bash = { 'shellcheck' },
        zsh = { 'zsh' },
        markdown = { 'markdownlint-cli2' },
        dockerfile = { 'hadolint' },
      }
      local function installed(name)
        local linter = lint.linters[name]
        if type(linter) == 'function' then
          linter = linter()
        end
        local cmd = type(linter) == 'table' and linter.cmd or name
        if type(cmd) == 'function' then
          cmd = cmd()
        end
        return vim.fn.executable(cmd) == 1
      end
      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
        group = vim.api.nvim_create_augroup('user_lint', { clear = true }),
        callback = function()
          local names = vim.tbl_filter(installed, lint.linters_by_ft[vim.bo.filetype] or {})
          if #names > 0 then
            lint.try_lint(names)
          end
        end,
      })
    end,
  },
}
