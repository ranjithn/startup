" Vim configuration with good defaults and plugins
set nocompatible
filetype off

" vim-plug plugin manager
call plug#begin('~/.vim/plugged')

" File explorer
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'

" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Code editing
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-repeat'
Plug 'jiangmiao/auto-pairs'

" Fuzzy finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Syntax highlighting
Plug 'sheerun/vim-polyglot'

" Color schemes
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'

call plug#end()

filetype plugin indent on
syntax on

" General settings
set number                      " Show line numbers
set relativenumber              " Show relative line numbers
set ruler                       " Show cursor position
set showcmd                     " Show command in bottom bar
set wildmenu                    " Visual autocomplete for command menu
set showmatch                   " Highlight matching brackets
set laststatus=2                " Always show status line
set encoding=utf-8              " Use UTF-8 encoding
set backspace=indent,eol,start  " Backspace over everything

" Search settings
set incsearch                   " Search as characters are entered
set hlsearch                    " Highlight search matches
set ignorecase                  " Ignore case in searches
set smartcase                   " Override ignorecase if search contains uppercase

" Indentation
set autoindent
set smartindent
set expandtab                   " Use spaces instead of tabs
set tabstop=4                   " Tab width
set shiftwidth=4                " Indentation width
set softtabstop=4               " Backspace removes 4 spaces

" UI settings
set mouse=a                     " Enable mouse support
set clipboard=unnamedplus       " Use system clipboard
set cursorline                  " Highlight current line
set scrolloff=8                 " Keep 8 lines above/below cursor
set sidescrolloff=8             " Keep 8 columns left/right of cursor
set signcolumn=yes              " Always show sign column

" File handling
set nobackup
set nowritebackup
set noswapfile
set autoread                    " Reload files changed outside vim
set hidden                      " Allow hidden buffers

" Performance
set lazyredraw                  " Don't redraw during macros
set updatetime=300              " Faster completion

" Color scheme
set background=dark
set termguicolors
colorscheme gruvbox
let g:airline_theme='gruvbox'

" Key mappings
let mapleader = ","
let maplocalleader = "\\"

" File operations
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" NERDTree
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>
let NERDTreeShowHidden=1
let NERDTreeIgnore=['\.pyc$', '\.pyo$', '\.o$', '__pycache__', 'node_modules']

" FZF
nnoremap <leader>p :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>

" Buffer navigation
nnoremap <leader>h :bprevious<CR>
nnoremap <leader>l :bnext<CR>
nnoremap <leader>d :bdelete<CR>

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Clear search highlighting
nnoremap <leader><space> :nohlsearch<CR>

" Quick escape
inoremap jk <ESC>

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Move lines up and down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" GitGutter settings
let g:gitgutter_enabled = 1
let g:gitgutter_map_keys = 0
nmap ]h <Plug>(GitGutterNextHunk)
nmap [h <Plug>(GitGutterPrevHunk)

" Airline settings
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

" Auto commands
augroup AutoCommands
    autocmd!
    " Remove trailing whitespace on save
    autocmd BufWritePre * :%s/\s\+$//e
    " Return to last edit position when opening files
    autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END
