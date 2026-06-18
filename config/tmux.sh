#!/bin/bash
# Tmux installation and configuration

install_tmux() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Tmux..."

    if command -v tmux &> /dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Tmux is already installed"
    elif [ "${IS_MACOS:-false}" = true ]; then
        maybe_run brew install tmux || { log_error "Failed to install tmux"; return 1; }
        log_success "Tmux installed successfully"
    else
        maybe_run $SUDO $PKG_INSTALL tmux || { log_error "Failed to install tmux"; return 1; }
        log_success "Tmux installed successfully"
    fi

    # Install clipboard support for tmux-yank
    if [ "${IS_MACOS:-false}" = true ]; then
        # macOS has pbcopy/pbpaste built in; tmux-yank uses them natively on macOS 10.12+
        log_success "macOS clipboard (pbcopy/pbpaste) is available for tmux-yank"
    else
        # Linux: install xclip for X11 clipboard support
        if command -v xclip &> /dev/null && [ "$FORCE_INSTALL" != true ]; then
            log_success "xclip is already installed"
        else
            log_info "Installing xclip (needed by tmux-yank)..."
            maybe_run $SUDO $PKG_INSTALL xclip || log_warning "Failed to install xclip — tmux-yank copy to clipboard won't work"
        fi
    fi
}

configure_tmux() {
    local tpm_path="${HOME}/.tmux/plugins/tpm"

    # Update mode: only update plugins
    if [ "$UPDATE_ONLY" = true ]; then
        if [ -d "$tpm_path" ]; then
            log_info "Updating Tmux plugins..."
            maybe_run "${tpm_path}/bin/update_plugins" all 2>/dev/null \
                || log_warning "Tmux plugin update failed (press 'Ctrl+a U' in tmux)"
        fi
        return 0
    fi

    log_info "Configuring Tmux..."

    # Install TPM (Tmux Plugin Manager)
    if [ ! -d "$tpm_path" ] || [ "$FORCE_INSTALL" = true ]; then
        log_info "Installing TPM (Tmux Plugin Manager)..."
        maybe_run git clone https://github.com/tmux-plugins/tpm "$tpm_path" 2>/dev/null \
            || log_warning "TPM installation failed"
    else
        log_success "TPM is already installed"
    fi

    # Check if .tmux.conf needs updating
    local needs_update=false
    if [ "$FORCE_INSTALL" = true ]; then
        needs_update=true
    elif [ ! -f "${HOME}/.tmux.conf" ]; then
        needs_update=true
    elif ! grep -q "tmux-plugins/tpm" "${HOME}/.tmux.conf" 2>/dev/null; then
        needs_update=true
    fi

    if [ "$needs_update" = true ]; then
        deploy_dotfile ".tmux.conf" || return 1
        log_success "Tmux configured successfully"
    else
        log_success "Tmux is already configured (skipping)"
    fi

    if [ -d "$tpm_path" ] && [ "$needs_update" = true ]; then
        log_info "Installing Tmux plugins..."
        maybe_run "${tpm_path}/bin/install_plugins" 2>/dev/null \
            || log_warning "Tmux plugin installation failed (press 'Ctrl+a I' in tmux)"
    fi
}

setup_tmux() {
    install_tmux
    configure_tmux
}
