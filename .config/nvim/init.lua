-- Leader must be set before lazy.nvim loads so plugin keymaps pick it up.
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

require('config.options')
require('config.keymaps')
require('config.autocmds')

-- The plugin setup relies on vim.lsp.config/enable and nvim-treesitter's main
-- branch, both of which need 0.11+. Older distro packages (e.g. apt on
-- Debian/Ubuntu) still get the options and keymaps above.
if vim.fn.has('nvim-0.11') == 1 then
  require('config.lazy')
else
  vim.notify('Neovim < 0.11: skipping plugins', vim.log.levels.WARN)
end
