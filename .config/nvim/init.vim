" vim:fdm=marker
"
" Paths on Windows:
"   config is C:\Users\User\AppData\Local\nvim
"   ~      is C:\Users\User\

" Non-plugin Customization ----------------------------------------------- {{{1

if has("win32")
    let g:config_path = '~/AppData/Local/nvim/'
else
    let g:config_path = '~/.config/nvim/'
endif

" Special characters
set showbreak=»
" eol:¬¶, trail:•¤
set listchars=nbsp:¬,tab:→\ ,extends:»,precedes:«,trail:-
set list          " Actually show the listchars above

" Set tabs to be 4 spaces
set tabstop=4
set shiftwidth=4
set expandtab

" Case insensitive unless we type caps
" (Force sensitivity by suffixing with \C if neccesary)
set ignorecase  " Need this for smartcase to work
set smartcase

" Show regex replace preview live as you type :%s/foo/bar/g
set inccommand=nosplit

" Support the mouse
set mouse=a

set number        " Show line numbers
set cursorline    " Highlight the line the current cursor is on

set hidden        " Switch buffers without abandoning changes or writing out
"
" Don't move the cursor back when exiting insert mode
autocmd InsertEnter * let CursorColumnI = col('.')
autocmd CursorMovedI * let CursorColumnI = col('.')
autocmd InsertLeave * if col('.') != CursorColumnI | call cursor(0, col('.')+1) | endif

" Faster diagnostic + completion feel (used by LSP)
set updatetime=300
set signcolumn=yes

" Non-plugin Remaps ------------------------------------------------------ {{{1

" Use jk/kj to exit insertion mode (Writing this line was fun!)
inoremap jk <esc>
inoremap kj <esc>

" Move up/down sensibly on wrapped lines
noremap j gj
noremap k gk

" Make Y behave as C and D do
noremap Y y$

" Pretty junky clipboard integration
" Windows: Make sure win32yank.exe is on your PATH.
nnoremap <S-Insert> "+P
inoremap <S-Insert> <esc>"+Pa
inoremap <C-v> <esc>"+Pa
vnoremap <C-c> "+y

" Quicksave sessions
map <F2> :mksession! ~/.vim_session <cr> " Quick write session with F2
map <F3> :source ~/.vim_session <cr>     " And load session with F3

" Spacemacs-esque Remaps -----------------

" Remap leader key to something easier to press (Space!)
let mapleader = ","
map <space> <leader>

" Remove highlighting
nnoremap <leader>sc :nohl<CR>

" Paste without auto-indent problems
nnoremap <leader>op :set invpaste paste?<CR>

" Toggle line numbers (and gitsigns column)
nnoremap <leader>tn :set invnumber<CR>:Gitsigns toggle_signs<CR>

" Shortcut to edit dotfiles
nnoremap <leader>fed :execute "e " . g:config_path . "init.vim"<CR>
nnoremap <leader>fex :execute "e ~/.nixos.dotfiles/configuration.nix"<CR>

" Filetype-specific
" TODO: Refactor so these aren't global..
nnoremap <leader>mt :Toc<CR>

" Jump back to previous buffer
inoremap <leader><TAB> :e#<CR>
nnoremap <leader><TAB> :e#<CR>

" Plugins ---------------------------------------------------------------- {{{1

" Automatically download vim-plug if we don't have it
if empty(glob(g:config_path . 'autoload/plug.vim'))
  execute '!curl -fLo ' . g:config_path . 'autoload/plug.vim --create-dirs' .
         \' https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | execute 'source '.g:config_path.'init.vim'
endif

call plug#begin('~/.local/share/nvim/plugged')

if !has('nvim')
    Plug 'tpope/vim-sensible'   " Sensible defaults. Neovim has this inbuilt.
endif

" Themes
Plug 'nanotech/jellybeans.vim'

" Status line (replaces vim-airline)
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-tree/nvim-web-devicons'

" Usability
Plug 'tpope/vim-commentary'     " Allow commenting blocks of code
Plug 'tpope/vim-surround'       " For manipulating surrounding text
Plug 'tpope/vim-vinegar'        " Enhance the default file explorer, netrw
Plug 'tpope/vim-unimpaired'     " misc shortcuts + new lines in normal mode

" Lua helpers (dependency for gitsigns/lspconfig)
Plug 'nvim-lua/plenary.nvim'

if has("win32")
    Plug 'ctrlpvim/ctrlp.vim'       " Jump around files
else
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
endif

" Git
Plug 'tpope/vim-fugitive'       " Git integration
Plug 'lewis6991/gitsigns.nvim'  " Gutter signs + hunks (replaces vim-gitgutter)

" LSP (replaces ALE)
Plug 'neovim/nvim-lspconfig'

Plug 'godlygeek/tabular'               " md: plasticboy/vim-markdown dependency
Plug 'plasticboy/vim-markdown'         " md: Markdown support
Plug 'junegunn/vim-easy-align'         " md: Align tables
" Stolen from https://robots.thoughtbot.com/align-github-flavored-markdown-tables-in-vim
au FileType markdown vmap <Leader><Bslash> :EasyAlign*<Bar><Enter>

" Initialize plugin system
call plug#end()

" Appearance and Themes -------------------------------------------------- {{{1

colorscheme jellybeans
set background=dark

set noshowmode  " lualine replaces the default vim mode line, so we don't need

" Fold markdown on the same line as the title, not the line after
let g:vim_markdown_folding_style_pythonic = 1
let g:vim_markdown_toc_autofit = 1    " Make ToC not take up half the screen

" Plugin remaps ---------------------------------------------------------- {{{1

function! s:find_git_root()
    return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
endfunction
command! ProjectFiles execute 'Files' s:find_git_root()
" Source: https://github.com/junegunn/fzf.vim/issues/47

" Git commands (fugitive)
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gb :Git blame<CR>

" pf : Open files in current project (See also: `:e .`)
" pr : Open files you have opened recently (See also: `:bro ol` or `:ol`)
" pb : Open a buffer that is already open (See also: `:ls`)
" pt : Open files in notes dir
if has("win32")
    nnoremap <leader>pf :CtrlP<CR>
    nnoremap <leader>pr :CtrlPMRU<CR>
    nnoremap <leader>pb :CtrlPBuffer<CR>
    nnoremap <leader>pt :CtrlP ~/txt<CR>
else
    nnoremap <leader>pf :ProjectFiles<CR>
    nnoremap <leader>pr :History<CR>
    nnoremap <leader>pb :Buffers<CR>
    nnoremap <leader>pt :FZF ~/txt<CR>
    nnoremap <leader>sp :Ag
endif

" Lua plugin configuration ----------------------------------------------- {{{1
"
" lualine, gitsigns, and LSP all use Lua for setup. Guard with has('nvim')
" so plain vim users (if any) don't choke on the heredoc.
if has('nvim')
lua << EOF

-- Status line ------------------------------------------------------------
require('lualine').setup({
  options = {
    theme = 'jellybeans',
    icons_enabled = true,
    component_separators = { left = '', right = '' },
    section_separators   = { left = '', right = '' },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
})

-- Git signs + hunks ------------------------------------------------------
require('gitsigns').setup({
  signcolumn     = true,
  numhl          = false,
  linehl         = false,
  current_line_blame = false,
  on_attach = function(bufnr)
    local gs = require('gitsigns')
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map('n', ']c', function() gs.next_hunk() end, 'Next git hunk')
    map('n', '[c', function() gs.prev_hunk() end, 'Prev git hunk')
    map('n', '<leader>hs', gs.stage_hunk,   'Stage hunk')
    map('n', '<leader>hr', gs.reset_hunk,   'Reset hunk')
    map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')
    map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
  end,
})

-- LSP --------------------------------------------------------------------
-- Enable language servers if their binaries are on PATH. No auto-install;
-- use mise/brew/npm to provide the servers you need:
--   npm i -g typescript typescript-language-server
--   brew install gopls rust-analyzer lua-language-server pyright
local lspconfig = require('lspconfig')
local servers = {
  ts_ls          = 'typescript-language-server',
  gopls          = 'gopls',
  rust_analyzer  = 'rust-analyzer',
  pyright        = 'pyright',
  lua_ls         = 'lua-language-server',
}
for server, binary in pairs(servers) do
  if vim.fn.executable(binary) == 1 then
    lspconfig[server].setup({})
  end
end

-- Bindings apply only when an LSP attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map('gd',          vim.lsp.buf.definition,      'LSP: go to definition')
    map('gD',          vim.lsp.buf.declaration,     'LSP: go to declaration')
    map('gr',          vim.lsp.buf.references,      'LSP: find references')
    map('gi',          vim.lsp.buf.implementation,  'LSP: go to implementation')
    map('K',           vim.lsp.buf.hover,           'LSP: hover')
    map('<leader>rn',  vim.lsp.buf.rename,          'LSP: rename')
    map('<leader>ca',  vim.lsp.buf.code_action,     'LSP: code action')
    map('<leader>lf',  function() vim.lsp.buf.format({ async = true }) end, 'LSP: format')
    map('[d',          vim.diagnostic.goto_prev,    'Prev diagnostic')
    map(']d',          vim.diagnostic.goto_next,    'Next diagnostic')
    map('<leader>le',  vim.diagnostic.open_float,   'Show diagnostic')
  end,
})

-- Nicer diagnostic display
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = '●' },
  severity_sort = true,
})

EOF
endif
