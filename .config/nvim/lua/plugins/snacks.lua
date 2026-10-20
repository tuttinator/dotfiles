-- snacks.nvim: picker (replaces fzf.vim/ctrlp), explorer (replaces neo-tree),
-- plus input/notifier UI used by other plugins and claudecode's terminal.
local function project_root()
  return vim.fs.root(0, '.git') or vim.uv.cwd()
end

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    input = { enabled = true },
    picker = { enabled = true },
    explorer = { enabled = true },
    notifier = { enabled = true },
  },
  keys = {
    -- pf/pr/pb/pt kept from the fzf.vim days
    {
      '<leader>pf',
      function()
        Snacks.picker.files({ cwd = project_root() })
      end,
      desc = 'Project files',
    },
    {
      '<leader>pr',
      function()
        Snacks.picker.recent()
      end,
      desc = 'Recent files',
    },
    {
      '<leader>pb',
      function()
        Snacks.picker.buffers()
      end,
      desc = 'Buffers',
    },
    {
      '<leader>pt',
      function()
        Snacks.picker.files({ cwd = '~/txt' })
      end,
      desc = 'Notes (~/txt)',
    },
    {
      '<leader>sp',
      function()
        Snacks.picker.grep({ cwd = project_root() })
      end,
      desc = 'Grep project',
    },
    {
      '<leader>sw',
      function()
        Snacks.picker.grep_word()
      end,
      desc = 'Grep word/selection',
      mode = { 'n', 'x' },
    },
    {
      '<leader>sh',
      function()
        Snacks.picker.help()
      end,
      desc = 'Help pages',
    },
    {
      '<leader>sk',
      function()
        Snacks.picker.keymaps()
      end,
      desc = 'Keymaps',
    },
    {
      '<leader>sd',
      function()
        Snacks.picker.diagnostics()
      end,
      desc = 'Diagnostics',
    },
    {
      '<leader>ss',
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = 'LSP symbols',
    },
    {
      '<leader>s/',
      function()
        Snacks.picker.resume()
      end,
      desc = 'Resume last picker',
    },

    -- File tree sidebar (same keys neo-tree had)
    {
      '<leader>ft',
      function()
        Snacks.explorer()
      end,
      desc = 'Toggle file tree',
    },
    {
      '<leader>ff',
      function()
        Snacks.explorer.reveal()
      end,
      desc = 'Reveal current file in tree',
    },
    {
      '<leader>fb',
      function()
        Snacks.picker.buffers()
      end,
      desc = 'Buffers',
    },
    {
      '<leader>fg',
      function()
        Snacks.picker.git_status()
      end,
      desc = 'Git status',
    },
  },
}
