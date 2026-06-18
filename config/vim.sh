#!/bin/bash
# Vim installation and configuration

install_vim() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Vim..."

    if command -v vim &> /dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Vim is already installed"
    else
        maybe_run $SUDO $PKG_INSTALL vim || { log_error "Failed to install vim"; return 1; }
        log_success "Vim installed successfully"
    fi
}

configure_vim() {
    # Update mode: only update plugins
    if [ "$UPDATE_ONLY" = true ]; then
        if [ -f "${HOME}/.vim/autoload/plug.vim" ]; then
            log_info "Updating Vim plugins..."
            maybe_run vim +PlugUpdate +qall 2>/dev/null \
                || log_warning "Vim plugin update failed (run ':PlugUpdate' manually)"
        fi
        return 0
    fi

    log_info "Configuring Vim..."

    # Install vim-plug (plugin manager)
    local vim_plug_path="${HOME}/.vim/autoload/plug.vim"
    if [ ! -f "$vim_plug_path" ] || [ "$FORCE_INSTALL" = true ]; then
        log_info "Installing vim-plug..."
        maybe_run curl -fLo "$vim_plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
            || log_warning "vim-plug download failed (run ':PlugInstall' manually after fixing network)"
    else
        log_success "vim-plug is already installed"
    fi

    # Check if .vimrc needs updating
    local needs_update=false
    if [ "$FORCE_INSTALL" = true ]; then
        needs_update=true
    elif [ ! -f "${HOME}/.vimrc" ]; then
        needs_update=true
    elif ! grep -q "call plug#begin" "${HOME}/.vimrc" 2>/dev/null; then
        needs_update=true
    fi

    if [ "$needs_update" = true ]; then
        deploy_dotfile ".vimrc" || return 1
        log_success "Vim configured successfully"
    else
        log_success "Vim is already configured (skipping)"
    fi

    if [ -f "${HOME}/.vim/autoload/plug.vim" ] && [ "$needs_update" = true ]; then
        log_info "Installing Vim plugins..."
        maybe_run vim +PlugInstall +qall 2>/dev/null \
            || log_warning "Vim plugin installation failed (run ':PlugInstall' manually)"
    fi
}

setup_vim() {
    install_vim
    configure_vim
}
