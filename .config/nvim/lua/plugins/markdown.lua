return {
  -- In-buffer rendering of headings, tables, code blocks, checkboxes.
  -- Raw markdown shows on the cursor line; <leader>mr toggles rendering.
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {},
    keys = {
      { '<leader>mr', '<cmd>RenderMarkdown toggle<CR>', ft = 'markdown', desc = 'Toggle markdown rendering' },
      -- Headings outline (was vim-markdown's :Toc)
      { '<leader>mt', 'gO', ft = 'markdown', remap = true, desc = 'Table of contents' },
    },
  },
}
