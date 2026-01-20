#!/bin/bash
# Zsh installation and configuration

install_zsh() {
    log_info "Installing Zsh..."
    
    if command -v zsh &> /dev/null; then
        log_success "Zsh is already installed"
    else
        $SUDO $PKG_INSTALL zsh
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
    log_info "Installing Zsh plugins..."
    
    local zsh_custom="${HOME}/.oh-my-zsh/custom"
    
    # zsh-autosuggestions
    if [ ! -d "${zsh_custom}/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "${zsh_custom}/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "${zsh_custom}/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${zsh_custom}/plugins/zsh-syntax-highlighting"
    fi
    
    # zsh-completions
    if [ ! -d "${zsh_custom}/plugins/zsh-completions" ]; then
        log_info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "${zsh_custom}/plugins/zsh-completions"
    fi
    
    # powerlevel10k theme
    if [ ! -d "${zsh_custom}/themes/powerlevel10k" ]; then
        log_info "Installing powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${zsh_custom}/themes/powerlevel10k"
    fi
    
    log_success "Zsh plugins installed successfully"
}

configure_zsh() {
    log_info "Configuring Zsh..."
    
    # Backup existing .zshrc
    backup_file "${HOME}/.zshrc"
    
    # Download and install .zshrc
    if [ -n "$RAW_BASE_URL" ]; then
        curl -fsSL "${RAW_BASE_URL}/dotfiles/.zshrc" -o "${HOME}/.zshrc"
    else
        # Fallback: create a basic .zshrc if running locally
        cat > "${HOME}/.zshrc" << 'EOF'
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

# Load powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
    fi
    
    log_success "Zsh configured successfully"
}

change_default_shell() {
    log_info "Changing default shell to Zsh..."
    
    local zsh_path=$(command -v zsh)
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells; then
        log_info "Adding Zsh to /etc/shells..."
        echo "$zsh_path" | $SUDO tee -a /etc/shells
    fi
    
    # Change default shell
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "Changing default shell to Zsh (may require password)..."
        chsh -s "$zsh_path" || log_warning "Failed to change shell. You can do this manually with: chsh -s $zsh_path"
        log_success "Default shell changed to Zsh (restart terminal to take effect)"
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
