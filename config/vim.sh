#!/bin/bash
# Vim installation and configuration

install_vim() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Vim..."

    if command -v vim &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Vim is already installed"
        return 0
    fi
    pkg_install vim || { log_error "Failed to install vim"; return 1; }
    log_success "Vim installed successfully"
}

configure_vim() {
    if [ "$UPDATE_ONLY" = true ]; then
        if [ -f "${HOME}/.vim/autoload/plug.vim" ]; then
            command -v git &>/dev/null || {
                log_warning "Git is not installed; Vim plugins cannot be updated"
                return 0
            }
            log_info "Updating Vim plugins..."
            maybe_run vim +PlugUpdate +qall 2>/dev/null \
                || log_warning "Vim plugin update failed (run ':PlugUpdate' manually)"
        fi
        return 0
    fi

    log_info "Configuring Vim..."
    local vim_plug_path="${HOME}/.vim/autoload/plug.vim"
    if [ ! -f "$vim_plug_path" ] || [ "$FORCE_INSTALL" = true ]; then
        log_info "Installing vim-plug..."
        maybe_run curl -fLo "$vim_plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
            || log_warning "vim-plug download failed"
    else
        log_success "vim-plug is already installed"
    fi

    deploy_dotfile .vimrc || return 1

    if [ -f "$vim_plug_path" ] && { [ "$DEPLOY_CHANGED" = true ] || [ "$FORCE_INSTALL" = true ]; }; then
        if ! command -v git &>/dev/null; then
            log_warning "Git is not installed; skipping Vim plugin installation"
        else
            log_info "Installing Vim plugins..."
            maybe_run vim +PlugInstall +qall 2>/dev/null \
                || log_warning "Vim plugin installation failed (run ':PlugInstall' manually)"
        fi
    fi
}

setup_vim() {
    install_vim || return 1
    configure_vim
}
