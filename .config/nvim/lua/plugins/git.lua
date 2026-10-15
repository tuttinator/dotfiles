return {
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G' },
    keys = {
      { '<leader>gs', '<cmd>Git<CR>', desc = 'Git status (fugitive)' },
      { '<leader>gb', '<cmd>Git blame<CR>', desc = 'Git blame' },
    },
  },

  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      on_attach = function(bufnr)
        local gs = require('gitsigns')
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        -- Fall through to the built-in ]c/[c in diff mode
        map('n', ']c', function()
          if vim.wo.diff then vim.cmd.normal({ ']c', bang = true }) else gs.nav_hunk('next') end
        end, 'Next git hunk')
        map('n', '[c', function()
          if vim.wo.diff then vim.cmd.normal({ '[c', bang = true }) else gs.nav_hunk('prev') end
        end, 'Prev git hunk')
        map('n', '<leader>hs', gs.stage_hunk, 'Stage hunk')
        map('n', '<leader>hr', gs.reset_hunk, 'Reset hunk')
        map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')
        map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
        map({ 'o', 'x' }, 'ih', gs.select_hunk, 'inside hunk')
      end,
    },
  },
}
