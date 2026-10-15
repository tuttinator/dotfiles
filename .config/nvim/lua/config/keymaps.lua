local map = vim.keymap.set

-- jk/kj to leave insert mode
map('i', 'jk', '<Esc>')
map('i', 'kj', '<Esc>')

-- Move by display line on wrapped text
map({ 'n', 'x' }, 'j', 'gj')
map({ 'n', 'x' }, 'k', 'gk')

-- Clipboard (Windows: put win32yank.exe on PATH)
map('n', '<S-Insert>', '"+P')
map('i', '<S-Insert>', '<Esc>"+Pa')
map('i', '<C-v>', '<Esc>"+Pa')
map('x', '<C-c>', '"+y')

-- Quick session save/load
map('n', '<F2>', '<cmd>mksession! ~/.vim_session<CR>', { desc = 'Save session' })
map('n', '<F3>', '<cmd>source ~/.vim_session<CR>', { desc = 'Load session' })

map('n', '<leader>sc', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
map('n', '<leader>op', '<cmd>set invpaste paste?<CR>', { desc = 'Toggle paste' })
map('n', '<leader>tn', '<cmd>set invnumber<CR><cmd>Gitsigns toggle_signs<CR>', { desc = 'Toggle numbers + git signs' })
map('n', '<leader>fed', function()
  vim.cmd.edit(vim.fn.stdpath('config') .. '/init.lua')
end, { desc = 'Edit nvim config' })
map('n', '<leader><Tab>', '<cmd>e #<CR>', { desc = 'Previous buffer' })

-- LSP: Neovim 0.11+ provides grn (rename), gra (code action), grr (references),
-- gri (implementation), grt (type definition), gO (symbols), K (hover),
-- [d / ]d (diagnostics) and <C-w>d (diagnostic float). These add the rest.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local function bmap(lhs, rhs, desc)
      map('n', lhs, rhs, { buffer = args.buf, desc = desc })
    end
    bmap('gd', vim.lsp.buf.definition, 'LSP: go to definition')
    bmap('gD', vim.lsp.buf.declaration, 'LSP: go to declaration')
    bmap('<leader>rn', vim.lsp.buf.rename, 'LSP: rename')
    bmap('<leader>ca', vim.lsp.buf.code_action, 'LSP: code action')
    bmap('<leader>le', vim.diagnostic.open_float, 'Show diagnostic')
  end,
})
