#!/bin/bash
# Zsh, Oh My Zsh, and shell plugin configuration

install_zsh() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Zsh..."

    if command -v zsh &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Zsh is already installed"
        return 0
    fi
    pkg_install zsh || { log_error "Failed to install zsh"; return 1; }
    log_success "Zsh installed successfully"
}

install_oh_my_zsh() {
    local omz_path="${HOME}/.oh-my-zsh"

    if [ "$UPDATE_ONLY" = true ]; then
        if [ -d "${omz_path}/.git" ]; then
            command -v git &>/dev/null || { log_warning "Git is unavailable; cannot update Oh My Zsh"; return 0; }
            maybe_run git -C "$omz_path" pull --ff-only 2>/dev/null \
                || log_warning "Oh My Zsh update failed"
        fi
        return 0
    fi

    log_info "Installing Oh My Zsh..."
    if [ -d "$omz_path" ]; then
        log_success "Oh My Zsh is already installed"
        return 0
    fi
    if ! command -v git &>/dev/null; then
        log_warning "Git is not installed; skipping Oh My Zsh"
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would install Oh My Zsh"
        return 0
    fi
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        || { log_error "Oh My Zsh installation failed"; return 1; }
    log_success "Oh My Zsh installed successfully"
}

install_zsh_plugins() {
    log_info "Checking Zsh plugins..."
    if ! command -v git &>/dev/null; then
        log_warning "Git is not installed; skipping Zsh plugin installation and updates"
        return 0
    fi

    local zsh_custom="${HOME}/.oh-my-zsh/custom"
    local plugins_updated=false

    _clone_or_update_plugin() {
        local name=$1 url=$2 path=$3
        if [ -d "$path" ]; then
            if [ "$UPDATE_ONLY" = true ] || [ "$FORCE_INSTALL" = true ]; then
                log_info "Updating $name..."
                maybe_run git -C "$path" pull --ff-only 2>/dev/null \
                    || log_warning "Failed to update $name"
                plugins_updated=true
            else
                log_success "$name is already installed"
            fi
        else
            log_info "Installing $name..."
            if maybe_run git clone --depth=1 "$url" "$path" 2>/dev/null; then
                plugins_updated=true
            else
                log_warning "Failed to install $name"
            fi
        fi
    }

    _clone_or_update_plugin zsh-autosuggestions \
        https://github.com/zsh-users/zsh-autosuggestions \
        "${zsh_custom}/plugins/zsh-autosuggestions"
    _clone_or_update_plugin zsh-syntax-highlighting \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${zsh_custom}/plugins/zsh-syntax-highlighting"
    _clone_or_update_plugin zsh-completions \
        https://github.com/zsh-users/zsh-completions \
        "${zsh_custom}/plugins/zsh-completions"
    _clone_or_update_plugin powerlevel10k \
        https://github.com/romkatv/powerlevel10k.git \
        "${zsh_custom}/themes/powerlevel10k"

    [ "$plugins_updated" = true ] && log_success "Zsh plugins updated"
}

configure_zsh() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Configuring Zsh..."
    deploy_dotfile .zshrc
}

change_default_shell() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Checking default shell..."

    local zsh_path
    zsh_path=$(command -v zsh 2>/dev/null || true)
    if [ -z "$zsh_path" ]; then
        log_warning "Zsh is not available; cannot change the default shell"
        return 0
    fi

    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        log_info "Adding Zsh to /etc/shells..."
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would append $zsh_path to /etc/shells"
        elif [ -n "${SUDO:-}" ]; then
            printf '%s\n' "$zsh_path" | "$SUDO" tee -a /etc/shells >/dev/null \
                || log_warning "Failed to add Zsh to /etc/shells"
        else
            printf '%s\n' "$zsh_path" >>/etc/shells \
                || log_warning "Failed to add Zsh to /etc/shells"
        fi
    fi

    if [ "${SHELL:-}" != "$zsh_path" ]; then
        log_info "Changing default shell to Zsh..."
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would run: chsh -s $zsh_path"
        elif chsh -s "$zsh_path"; then
            log_success "Default shell changed; restart the login session"
        else
            log_warning "Could not change the shell. Run manually: chsh -s $zsh_path"
        fi
    else
        log_success "Zsh is already the default shell"
    fi
}

setup_zsh() {
    install_zsh || return 1
    install_oh_my_zsh || return 1
    install_zsh_plugins
    configure_zsh || return 1
    change_default_shell
}
