#!/bin/bash
# Linux Development Environment Installer
# This script installs and configures vim, tmux, and zsh with good defaults and plugins
# 
# Usage:
#   Local:  bash linux_installer.sh
#   Remote: curl -fsSL https://raw.githubusercontent.com/username/startup/main/linux_installer.sh | bash
#
# The script is modular and can be easily extended for additional tools

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Linux Development Environment Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Determine if running from curl or locally
if [ -t 0 ]; then
    # Running locally
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOCAL_MODE=true
else
    # Running from curl
    SCRIPT_DIR="/tmp/startup_installer_$$"
    LOCAL_MODE=false
    mkdir -p "$SCRIPT_DIR"
    cd "$SCRIPT_DIR"
fi

# Function to source config files
source_config() {
    local config_file=$1
    if [ "$LOCAL_MODE" = true ]; then
        source "${SCRIPT_DIR}/config/${config_file}"
    else
        # Download config file when running remotely
        local url="${RAW_BASE_URL}/config/${config_file}"
        curl -fsSL "$url" -o "${SCRIPT_DIR}/${config_file}"
        source "${SCRIPT_DIR}/${config_file}"
    fi
}

# Set GitHub variables for remote execution
if [ "$LOCAL_MODE" = false ]; then
    export GITHUB_USER="${GITHUB_USER:-ranjithn}"
    export GITHUB_REPO="${GITHUB_REPO:-startup}"
    export GITHUB_BRANCH="${GITHUB_BRANCH:-dev}"
    export RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
fi

# Load variables and utility functions
source_config "variables.sh"

# Detect package manager
detect_package_manager

# Check for sudo/root
check_sudo

# Update package manager
log_info "Updating package manager..."
$SUDO $PKG_UPDATE

# Install git if not present (required for plugins)
if ! command -v git &> /dev/null; then
    log_info "Installing git..."
    $SUDO $PKG_INSTALL git
fi

# Install curl if not present
if ! command -v curl &> /dev/null; then
    log_info "Installing curl..."
    $SUDO $PKG_INSTALL curl
fi

# Load and run module installations
log_info "Loading installation modules..."

source_config "vim.sh"
source_config "tmux.sh"
source_config "zsh.sh"

# Execute installations
echo ""
log_info "Starting installations..."
echo ""

setup_vim
echo ""

setup_tmux
echo ""

setup_zsh
echo ""

# Cleanup if running from curl
if [ "$LOCAL_MODE" = false ]; then
    cd /tmp
    rm -rf "$SCRIPT_DIR"
fi

# Final message
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
log_success "All tools have been installed and configured"
log_info "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. For Vim: Run ':PlugInstall' inside vim if plugins didn't install"
echo "  3. For Tmux: Press 'prefix + I' (Ctrl+a then I) to install plugins"
echo "  4. For Zsh: Run 'p10k configure' to customize your prompt"
echo ""
log_warning "Note: If your shell didn't change, run: chsh -s \$(which zsh)"
echo ""
