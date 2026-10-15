return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = false,
    priority = 1000,
    config = function()
      -- Matches the catppuccin-mocha iTerm2 profile in this repo.
      -- Integrations for installed plugins are detected automatically.
      require('catppuccin').setup({ flavour = 'mocha' })
      vim.cmd.colorscheme('catppuccin')
    end,
  },

  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    opts = {
      options = {
        theme = 'auto', -- follows the colourscheme
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
    },
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      preset = 'helix',
      spec = {
        { '<leader>a', group = 'AI / Claude Code' },
        { '<leader>c', group = 'code' },
        { '<leader>f', group = 'files' },
        { '<leader>g', group = 'git' },
        { '<leader>h', group = 'hunks' },
        { '<leader>l', group = 'lsp' },
        { '<leader>m', group = 'markdown' },
        { '<leader>p', group = 'pick' },
        { '<leader>s', group = 'search' },
        { '<leader>t', group = 'toggle' },
        { 'gr', group = 'lsp' },
      },
    },
  },
}
