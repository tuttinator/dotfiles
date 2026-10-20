local group = vim.api.nvim_create_augroup('user_config', { clear = true })

-- Don't move the cursor back a column when leaving insert mode
local insert_col
vim.api.nvim_create_autocmd({ 'InsertEnter', 'CursorMovedI' }, {
  group = group,
  callback = function()
    insert_col = vim.fn.col('.')
  end,
})
vim.api.nvim_create_autocmd('InsertLeave', {
  group = group,
  callback = function()
    if vim.fn.col('.') ~= insert_col then
      vim.fn.cursor(0, vim.fn.col('.') + 1)
    end
  end,
})

-- Briefly highlight yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
})

vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = '●' },
  severity_sort = true,
})
