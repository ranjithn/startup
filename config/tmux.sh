#!/bin/bash
# Tmux installation and configuration. Clipboard integration uses OSC 52;
# no X11 or Wayland packages are installed on server systems.

install_tmux() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Tmux..."

    if command -v tmux &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Tmux is already installed"
        return 0
    fi
    pkg_install tmux || { log_error "Failed to install tmux"; return 1; }
    log_success "Tmux installed successfully"
}

configure_tmux() {
    local tpm_path="${HOME}/.tmux/plugins/tpm"

    if [ "$UPDATE_ONLY" = true ]; then
        if [ -d "$tpm_path" ]; then
            command -v git &>/dev/null || {
                log_warning "Git is not installed; Tmux plugins cannot be updated"
                return 0
            }
            log_info "Updating Tmux plugins..."
            maybe_run "${tpm_path}/bin/update_plugins" all 2>/dev/null \
                || log_warning "Tmux plugin update failed"
        fi
        return 0
    fi

    log_info "Configuring Tmux..."
    if [ -d "$tpm_path" ]; then
        if [ "$FORCE_INSTALL" = true ] && command -v git &>/dev/null; then
            maybe_run git -C "$tpm_path" pull --ff-only 2>/dev/null \
                || log_warning "TPM update failed"
        else
            log_success "TPM is already installed"
        fi
    elif ! command -v git &>/dev/null; then
        log_warning "Git is not installed; skipping TPM and Tmux plugins"
    else
        log_info "Installing TPM..."
        maybe_run git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_path" 2>/dev/null \
            || log_warning "TPM installation failed"
    fi

    deploy_dotfile .tmux.conf || return 1

    if [ -d "$tpm_path" ] && { [ "$DEPLOY_CHANGED" = true ] || [ "$FORCE_INSTALL" = true ]; }; then
        log_info "Installing Tmux plugins..."
        maybe_run "${tpm_path}/bin/install_plugins" 2>/dev/null \
            || log_warning "Tmux plugin installation failed (press 'Ctrl+a I' in tmux)"
    fi
}

setup_tmux() {
    install_tmux || return 1
    configure_tmux
}
