local opt = vim.opt

-- Special characters
opt.showbreak = '»'
opt.listchars = { nbsp = '¬', tab = '→ ', extends = '»', precedes = '«', trail = '-' }
opt.list = true

-- Tabs are 4 spaces (conform/LSP formatters override per filetype)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- Case insensitive unless we type caps (force with \C)
opt.ignorecase = true
opt.smartcase = true

-- Live preview of :%s/foo/bar/g
opt.inccommand = 'nosplit'

opt.mouse = 'a'
opt.number = true
opt.cursorline = true
opt.signcolumn = 'yes'
opt.updatetime = 300
opt.termguicolors = true

-- lualine shows the mode
opt.showmode = false

-- Treesitter folds (set per buffer in plugins/treesitter.lua) start open
opt.foldlevelstart = 99

-- Persistent undo across sessions
opt.undofile = true
