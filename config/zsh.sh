#!/bin/bash
# Zsh installation and configuration

install_zsh() {
    log_info "Installing Zsh..."
    
    if command -v zsh &> /dev/null; then
        log_success "Zsh is already installed"
    else
        $SUDO $PKG_INSTALL zsh || { log_error "Failed to install zsh"; return 1; }
        log_success "Zsh installed successfully"
    fi
}

install_oh_my_zsh() {
    log_info "Installing Oh My Zsh..."
    
    if [ -d "${HOME}/.oh-my-zsh" ]; then
        log_success "Oh My Zsh is already installed"
    else
        # Install Oh My Zsh without changing shell or running zsh
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log_success "Oh My Zsh installed successfully"
    fi
}

install_zsh_plugins() {
    log_info "Checking Zsh plugins..."
    
    local zsh_custom="${HOME}/.oh-my-zsh/custom"
    local plugins_updated=false
    
    # zsh-autosuggestions
    if [ ! -d "${zsh_custom}/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "${zsh_custom}/plugins/zsh-autosuggestions" 2>/dev/null && plugins_updated=true
    else
        log_success "zsh-autosuggestions already installed"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "${zsh_custom}/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${zsh_custom}/plugins/zsh-syntax-highlighting" 2>/dev/null && plugins_updated=true
    else
        log_success "zsh-syntax-highlighting already installed"
    fi
    
    # zsh-completions
    if [ ! -d "${zsh_custom}/plugins/zsh-completions" ]; then
        log_info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "${zsh_custom}/plugins/zsh-completions" 2>/dev/null && plugins_updated=true
    else
        log_success "zsh-completions already installed"
    fi
    
    # powerlevel10k theme
    if [ ! -d "${zsh_custom}/themes/powerlevel10k" ]; then
        log_info "Installing powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${zsh_custom}/themes/powerlevel10k" 2>/dev/null && plugins_updated=true
    else
        log_success "powerlevel10k already installed"
    fi
    
    if [ "$plugins_updated" = true ]; then
        log_success "Zsh plugins updated"
    else
        log_success "All Zsh plugins already installed"
    fi
}

configure_zsh() {
    log_info "Configuring Zsh..."
    
    # Check if .zshrc needs updating
    local needs_update=false
    if [ ! -f "${HOME}/.zshrc" ]; then
        needs_update=true
    elif [ -n "$RAW_BASE_URL" ]; then
        # Check if managed by this installer (contains oh-my-zsh marker)
        if ! grep -q "oh-my-zsh" "${HOME}/.zshrc" 2>/dev/null; then
            needs_update=true
        fi
    fi
    
    if [ "$needs_update" = true ]; then
        # Backup existing .zshrc
        backup_file "${HOME}/.zshrc"
        
        # Download and install .zshrc
        if [ -n "$RAW_BASE_URL" ]; then
            curl -fsSL "${RAW_BASE_URL}/dotfiles/.zshrc" -o "${HOME}/.zshrc" \
                || { log_error "Failed to download .zshrc"; return 1; }
    else
        # Fallback: create a basic .zshrc if running locally
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
        log_success "Zsh configured successfully"
    else
        log_success "Zsh is already configured (skipping)"
    fi
}

change_default_shell() {
    log_info "Checking default shell..."
    
    local zsh_path=$(command -v zsh)
    
    # Check if zsh is in /etc/shells
    if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
        log_info "Adding Zsh to /etc/shells..."
        echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null 2>&1 || log_warning "Failed to add Zsh to /etc/shells"
    else
        log_success "Zsh is already in /etc/shells"
    fi
    
    # Change default shell only if not already set
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "Changing default shell to Zsh (may require password)..."
        if chsh -s "$zsh_path" 2>/dev/null; then
            log_success "Default shell changed to Zsh (restart terminal to take effect)"
        else
            log_warning "Failed to change shell automatically. Run manually: chsh -s $zsh_path"
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
