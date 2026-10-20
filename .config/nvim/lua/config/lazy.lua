local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Loads every file in lua/plugins/
require('lazy').setup('plugins', {
  install = { colorscheme = { 'base16-tomorrow-night' } },
  change_detection = { notify = false },
})
