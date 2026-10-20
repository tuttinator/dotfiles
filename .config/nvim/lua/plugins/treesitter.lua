-- nvim-treesitter `main` branch: it only installs parsers and queries;
-- highlighting/folds/indent are switched on per buffer below.
-- Needs `tree-sitter` CLI (brew "tree-sitter-cli") and a C compiler.
local parsers = {
  'bash',
  'c',
  'css',
  'diff',
  'dockerfile',
  'elixir',
  'go',
  'gomod',
  'html',
  'javascript',
  'jsdoc',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'python',
  'query',
  'regex',
  'ruby',
  'rust',
  'sql',
  'swift',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install(parsers)

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('user_treesitter', { clear = true }),
        callback = function(args)
          -- Only start if a parser is available for this filetype
          if not pcall(vim.treesitter.start, args.buf) then
            return
          end
          vim.wo.foldmethod = 'expr'
          vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    event = 'VeryLazy',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local select = require('nvim-treesitter-textobjects.select')
      local move = require('nvim-treesitter-textobjects.move')
      local objects = {
        f = 'function',
        c = 'class',
        a = 'parameter',
        l = 'loop',
        i = 'conditional',
      }
      for key, name in pairs(objects) do
        vim.keymap.set({ 'x', 'o' }, 'a' .. key, function()
          select.select_textobject('@' .. name .. '.outer', 'textobjects')
        end, { desc = 'around ' .. name })
        vim.keymap.set({ 'x', 'o' }, 'i' .. key, function()
          select.select_textobject('@' .. name .. '.inner', 'textobjects')
        end, { desc = 'inside ' .. name })
      end

      -- ]m/[m functions, ]M/[M classes. (unimpaired owns ]f ]a ]C etc.,
      -- gitsigns owns ]c)
      local jumps = { m = '@function.outer', M = '@class.outer' }
      for key, query in pairs(jumps) do
        vim.keymap.set({ 'n', 'x', 'o' }, ']' .. key, function()
          move.goto_next_start(query, 'textobjects')
        end, { desc = 'Next ' .. query })
        vim.keymap.set({ 'n', 'x', 'o' }, '[' .. key, function()
          move.goto_previous_start(query, 'textobjects')
        end, { desc = 'Prev ' .. query })
      end
    end,
  },
}
