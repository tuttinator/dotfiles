return {
  { 'tpope/vim-surround', event = 'VeryLazy' },
  { 'tpope/vim-unimpaired', event = 'VeryLazy' },

  -- Ctrl-h/j/k/l moves between nvim splits and tmux panes alike
  -- (tmux side is the same plugin, loaded via TPM in tmux.conf)
  {
    'christoomey/vim-tmux-navigator',
    cmd = { 'TmuxNavigateLeft', 'TmuxNavigateDown', 'TmuxNavigateUp', 'TmuxNavigateRight', 'TmuxNavigatePrevious' },
    keys = {
      { '<C-h>', '<cmd>TmuxNavigateLeft<CR>', desc = 'Window/pane left' },
      { '<C-j>', '<cmd>TmuxNavigateDown<CR>', desc = 'Window/pane down' },
      { '<C-k>', '<cmd>TmuxNavigateUp<CR>', desc = 'Window/pane up' },
      { '<C-l>', '<cmd>TmuxNavigateRight<CR>', desc = 'Window/pane right' },
    },
  },

  -- `-` opens the parent directory as an editable buffer (replaces vinegar)
  {
    'stevearc/oil.nvim',
    lazy = false, -- so `nvim some/dir` opens in oil
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      view_options = { show_hidden = true },
    },
    keys = {
      { '-', '<cmd>Oil<CR>', desc = 'Open parent directory' },
    },
  },

  -- Align markdown tables: select, then <leader>\
  {
    'junegunn/vim-easy-align',
    keys = {
      { '<leader>\\', ':EasyAlign*<Bar><CR>', mode = 'x', ft = 'markdown', desc = 'Align markdown table' },
    },
  },
}
