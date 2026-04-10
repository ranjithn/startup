#!/bin/bash
# Zsh installation and configuration

install_zsh() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Zsh..."

    if command -v zsh &> /dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Zsh is already installed"
    else
        maybe_run $SUDO $PKG_INSTALL zsh || { log_error "Failed to install zsh"; return 1; }
        log_success "Zsh installed successfully"
    fi
}

install_oh_my_zsh() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Oh My Zsh..."

    if [ -d "${HOME}/.oh-my-zsh" ] && [ "$FORCE_INSTALL" != true ]; then
        log_success "Oh My Zsh is already installed"
    else
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would install Oh My Zsh"
        else
            RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            log_success "Oh My Zsh installed successfully"
        fi
    fi
}

install_zsh_plugins() {
    log_info "Checking Zsh plugins..."

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
                log_success "$name already installed"
            fi
        else
            log_info "Installing $name..."
            maybe_run git clone --depth=1 "$url" "$path" 2>/dev/null && plugins_updated=true \
                || log_warning "Failed to install $name"
        fi
    }

    _clone_or_update_plugin "zsh-autosuggestions" \
        https://github.com/zsh-users/zsh-autosuggestions \
        "${zsh_custom}/plugins/zsh-autosuggestions"

    _clone_or_update_plugin "zsh-syntax-highlighting" \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${zsh_custom}/plugins/zsh-syntax-highlighting"

    _clone_or_update_plugin "zsh-completions" \
        https://github.com/zsh-users/zsh-completions \
        "${zsh_custom}/plugins/zsh-completions"

    _clone_or_update_plugin "powerlevel10k" \
        "https://github.com/romkatv/powerlevel10k.git" \
        "${zsh_custom}/themes/powerlevel10k"

    if [ "$plugins_updated" = true ]; then
        log_success "Zsh plugins updated"
    else
        log_success "All Zsh plugins already installed"
    fi
}

configure_zsh() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Configuring Zsh..."

    # Check if .zshrc needs updating
    local needs_update=false
    if [ "$FORCE_INSTALL" = true ]; then
        needs_update=true
    elif [ ! -f "${HOME}/.zshrc" ]; then
        needs_update=true
    elif ! grep -q "oh-my-zsh" "${HOME}/.zshrc" 2>/dev/null; then
        needs_update=true
    elif ! grep -q "powerlevel10k/powerlevel10k" "${HOME}/.zshrc" 2>/dev/null; then
        needs_update=true
    fi

    if [ "$needs_update" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would backup and deploy .zshrc"
        else
            backup_file "${HOME}/.zshrc"
            if [ -n "$RAW_BASE_URL" ]; then
                curl -fsSL "${RAW_BASE_URL}/dotfiles/.zshrc" -o "${HOME}/.zshrc" \
                    || { log_error "Failed to download .zshrc"; return 1; }
            else
                cat > "${HOME}/.zshrc" << 'EOF'
# Enable Powerlevel10k instant prompt (must be at top of .zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    docker
    docker-compose
    kubectl
    terraform
    sudo
    history
    command-not-found
    colored-man-pages
)

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
export VISUAL='vim'

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias tmux='tmux -2'

# Custom functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
            fi
        fi
        log_success "Zsh configured successfully"
    else
        log_success "Zsh is already configured (skipping)"
    fi
}

change_default_shell() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Checking default shell..."

    local zsh_path=$(command -v zsh)

    # Check if zsh is in /etc/shells
    if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
        log_info "Adding Zsh to /etc/shells..."
        maybe_run bash -c "echo '$zsh_path' | $SUDO tee -a /etc/shells >/dev/null 2>&1" \
            || log_warning "Failed to add Zsh to /etc/shells"
    else
        log_success "Zsh is already in /etc/shells"
    fi

    # Change default shell only if not already set
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "Changing default shell to Zsh (may require password)..."
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would run: chsh -s $zsh_path"
        elif chsh -s "$zsh_path" 2>/dev/null; then
            log_success "Default shell changed to Zsh (restart terminal to take effect)"
        else
            log_warning "Failed to change shell automatically. Run manually: chsh -s $zsh_path"
            if [ "$(whoami)" = "azureuser" ]; then
                if grep -q "exec zsh" "${HOME}/.bashrc" 2>/dev/null; then
                    log_success "exec zsh already present in ~/.bashrc"
                else
                    log_info "Falling back to exec zsh in ~/.bashrc..."
                    maybe_run bash -c "echo 'exec zsh' >> ${HOME}/.bashrc" \
                        && log_success "Added 'exec zsh' to ~/.bashrc (takes effect on next login)" \
                        || log_warning "Failed to update ~/.bashrc"
                fi
            fi
        fi
    else
        log_success "Zsh is already the default shell"
    fi
}

setup_zsh() {
    install_zsh
    install_oh_my_zsh
    install_zsh_plugins
    configure_zsh
    change_default_shell
}
