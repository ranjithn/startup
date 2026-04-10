#!/bin/bash
# Tmux installation and configuration

install_tmux() {
    log_info "Installing Tmux..."
    
    if command -v tmux &> /dev/null; then
        log_success "Tmux is already installed"
    else
        $SUDO $PKG_INSTALL tmux || { log_error "Failed to install tmux"; return 1; }
        log_success "Tmux installed successfully"
    fi
}

configure_tmux() {
    log_info "Configuring Tmux..."
    
    # Install TPM (Tmux Plugin Manager)
    local tpm_path="${HOME}/.tmux/plugins/tpm"
    if [ ! -d "$tpm_path" ]; then
        log_info "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_path" 2>/dev/null || log_warning "TPM installation failed"
    else
        log_success "TPM is already installed"
    fi
    
    # Check if .tmux.conf needs updating
    local needs_update=false
    if [ ! -f "${HOME}/.tmux.conf" ]; then
        needs_update=true
    elif [ -n "$RAW_BASE_URL" ]; then
        # Check if managed by this installer (contains tpm marker)
        if ! grep -q "tmux-plugins/tpm" "${HOME}/.tmux.conf" 2>/dev/null; then
            needs_update=true
        fi
    fi
    
    if [ "$needs_update" = true ]; then
        # Backup existing .tmux.conf
        backup_file "${HOME}/.tmux.conf"
        
        # Download and install .tmux.conf
        if [ -n "$RAW_BASE_URL" ]; then
            curl -fsSL "${RAW_BASE_URL}/dotfiles/.tmux.conf" -o "${HOME}/.tmux.conf" \
                || { log_error "Failed to download .tmux.conf"; return 1; }
    else
        # Fallback: create a basic .tmux.conf if running locally
        cat > "${HOME}/.tmux.conf" << 'EOF'
# Tmux configuration

# Change prefix from C-b to C-a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Enable mouse mode
set -g mouse on

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Vi mode
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# Status bar
set -g status-position bottom
set -g status-bg colour234
set -g status-fg colour137
set -g status-left ''
set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
set -g status-right-length 50
set -g status-left-length 20

setw -g window-status-current-format ' #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

# Increase scrollback buffer size
set -g history-limit 10000

# Faster command sequences
set -s escape-time 0

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'

# Initialize TPM (keep this line at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
EOF
        fi
        log_success "Tmux configured successfully"
    else
        log_success "Tmux is already configured (skipping)"
    fi
    
    # Install/update plugins if TPM is present and config was updated
    if [ -d "$tpm_path" ] && [ "$needs_update" = true ]; then
        log_info "Installing Tmux plugins..."
        "${tpm_path}/bin/install_plugins" 2>/dev/null || log_warning "Tmux plugin installation failed (press 'Ctrl+a I' in tmux to install)"
    fi
}

setup_tmux() {
    install_tmux
    configure_tmux
}
