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

" lualine replaces the default vim mode line, so we don't need the -- INSERT --
set noshowmode

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

" Plugins (lazy.nvim) ---------------------------------------------------- {{{1

lua << EOF
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins')
EOF

" Plugin remaps ---------------------------------------------------------- {{{1

" Align github-flavored markdown tables (vim-easy-align)
" Stolen from https://robots.thoughtbot.com/align-github-flavored-markdown-tables-in-vim
au FileType markdown vmap <Leader><Bslash> :EasyAlign*<Bar><Enter>

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
