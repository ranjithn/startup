#!/bin/bash
# macOS Development Environment Installer
# This script installs and configures vim, tmux, zsh, and docker with good defaults and plugins
#
# Prerequisites: Homebrew must be installed (https://brew.sh)
#
# Usage:
#   Local:  bash macos_installer.sh [options]
#   Remote: curl -fsSL https://raw.githubusercontent.com/ranjithn/startup/refs/heads/master/macos_installer.sh | bash
#
# Options:
#   --force    Reinstall everything, even if already present
#   --update   Update plugins only, skip package installs and configs
#   --dry-run  Show what would be done without making changes
#   -h, --help Show this help message

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Require macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: This installer is for macOS only. Use linux_installer.sh on Linux.${NC}"
    exit 1
fi

# Parse arguments
FORCE_INSTALL=false
UPDATE_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)   FORCE_INSTALL=true ;;
        --update)  UPDATE_ONLY=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --force    Reinstall everything, even if already present"
            echo "  --update   Update plugins only, skip package installs and configs"
            echo "  --dry-run  Show what would be done without making changes"
            echo "  -h, --help Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
    shift
done
export FORCE_INSTALL UPDATE_ONLY DRY_RUN

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  macOS Development Environment Setup${NC}"
echo -e "${BLUE}======================================${NC}"
[ "$DRY_RUN" = true ]       && echo -e "${BLUE}  [DRY-RUN MODE - no changes will be made]${NC}"
[ "$FORCE_INSTALL" = true ] && echo -e "${BLUE}  [FORCE mode - reinstalling everything]${NC}"
[ "$UPDATE_ONLY" = true ]   && echo -e "${BLUE}  [UPDATE mode - plugins only]${NC}"
echo ""

# Determine if running from curl or locally
if [ -t 0 ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOCAL_MODE=true
else
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
        local url="${RAW_BASE_URL}/config/${config_file}"
        curl -fsSL "$url" -o "${SCRIPT_DIR}/${config_file}"
        source "${SCRIPT_DIR}/${config_file}"
    fi
}

# Set GitHub variables for remote execution
if [ "$LOCAL_MODE" = false ]; then
    export GITHUB_USER="${GITHUB_USER:-ranjithn}"
    export GITHUB_REPO="${GITHUB_REPO:-startup}"
    export GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
    export RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${GITHUB_BRANCH}"
fi

# Load variables and utility functions
source_config "variables.sh"

# Detect package manager (will set IS_MACOS=true and PKG_MANAGER=brew)
detect_package_manager
check_sudo

if [ "$UPDATE_ONLY" != true ]; then
    log_info "Updating Homebrew..."
    maybe_run brew update 2>/dev/null || log_warning "brew update had issues (continuing anyway)"

    if ! command -v git &> /dev/null; then
        log_info "Installing git..."
        maybe_run brew install git || log_error "Failed to install git"
    else
        log_success "git is already installed"
    fi

    if ! command -v curl &> /dev/null; then
        log_info "Installing curl..."
        maybe_run brew install curl || log_error "Failed to install curl"
    else
        log_success "curl is already installed"
    fi
fi

# Load and run module installations
log_info "Loading installation modules..."

source_config "vim.sh"
source_config "tmux.sh"
source_config "zsh.sh"
source_config "docker.sh"

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

setup_docker
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

if [ "$UPDATE_ONLY" != true ]; then
    log_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. For Vim:   Run ':PlugInstall' inside vim if plugins didn't install"
    echo "  3. For Tmux:  Press 'prefix + I' (Ctrl+a then I) to install plugins"
    echo "  4. For Zsh:   Run 'p10k configure' to customize your prompt"
    echo "  5. For Docker: Launch Docker Desktop from Applications"
    echo ""
    log_warning "Note: If your shell didn't change, run: chsh -s \$(which zsh)"
fi
echo ""
