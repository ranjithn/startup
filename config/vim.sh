#!/bin/bash
# Vim installation and configuration

install_vim() {
    log_info "Installing Vim..."
    
    if command -v vim &> /dev/null; then
        log_success "Vim is already installed"
    else
        $SUDO $PKG_INSTALL vim
        log_success "Vim installed successfully"
    fi
}

configure_vim() {
    log_info "Configuring Vim..."
    
    # Backup existing .vimrc
    backup_file "${HOME}/.vimrc"
    
    # Install vim-plug (plugin manager)
    local vim_plug_path="${HOME}/.vim/autoload/plug.vim"
    if [ ! -f "$vim_plug_path" ]; then
        log_info "Installing vim-plug..."
        curl -fLo "$vim_plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    
    # Download and install .vimrc
    if [ -n "$RAW_BASE_URL" ]; then
        curl -fsSL "${RAW_BASE_URL}/dotfiles/.vimrc" -o "${HOME}/.vimrc"
    else
        # Fallback: create a basic .vimrc if running locally
        cat > "${HOME}/.vimrc" << 'EOF'
" Vim configuration
set nocompatible
filetype off

" vim-plug plugins
call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'airblade/vim-gitgutter'
call plug#end()

filetype plugin indent on
syntax on

" General settings
set number
set relativenumber
set ruler
set showcmd
set incsearch
set hlsearch
set ignorecase
set smartcase
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set mouse=a
set clipboard=unnamedplus
set cursorline
set wildmenu
set laststatus=2
set encoding=utf-8
set backspace=indent,eol,start

" Theme
set background=dark
colorscheme desert

" Key mappings
let mapleader = ","
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
EOF
    fi
    
    # Install plugins
    log_info "Installing Vim plugins..."
    vim +PlugInstall +qall 2>/dev/null || true
    
    log_success "Vim configured successfully"
}

setup_vim() {
    install_vim
    configure_vim
}
