#!/bin/bash
# macOS Development Environment Installer
# This script installs and configures vim, tmux, and zsh with good defaults and plugins.
# Docker is intentionally NOT installed — install Docker Desktop / OrbStack / Colima yourself.
#
# Prerequisites: none — Homebrew is bootstrapped automatically if missing.
#
# Usage:
#   Local:  bash macos_installer.sh [options]
#   Remote: pin GITHUB_REF and the script URL to the same commit; see README.md
#
# Options:
#   --force    Reinstall everything, even if already present
#   --update   Update plugins only, skip package installs and configs
#   --dry-run          Show what would be done without making changes
#   --generate-ssh-key Interactively generate a client SSH key if missing
#   -h, --help         Show this help message

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Require macOS on Apple Silicon. Intel Macs are intentionally not supported —
# brew paths, casks, and bottles are assumed to be arm64.
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: This installer is for macOS only. Use linux_installer.sh on Linux.${NC}"
    exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
    echo -e "${RED}Error: This installer targets Apple Silicon (arm64) only; detected $(uname -m).${NC}"
    exit 1
fi

# Parse arguments
FORCE_INSTALL=false
UPDATE_ONLY=false
DRY_RUN=false
GENERATE_SSH_KEY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)   FORCE_INSTALL=true ;;
        --update)  UPDATE_ONLY=true ;;
        --dry-run)          DRY_RUN=true ;;
        --generate-ssh-key) GENERATE_SSH_KEY=true ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --force    Reinstall everything, even if already present"
            echo "  --update   Update plugins only, skip package installs and configs"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --generate-ssh-key Interactively generate a client SSH key if missing"
            echo "  -h, --help         Show this help message"
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
export FORCE_INSTALL UPDATE_ONLY DRY_RUN GENERATE_SSH_KEY

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  macOS Development Environment Setup${NC}"
echo -e "${BLUE}======================================${NC}"
[ "$DRY_RUN" = true ]       && echo -e "${BLUE}  [DRY-RUN MODE - no changes will be made]${NC}"
[ "$FORCE_INSTALL" = true ] && echo -e "${BLUE}  [FORCE mode - reinstalling everything]${NC}"
[ "$UPDATE_ONLY" = true ]   && echo -e "${BLUE}  [UPDATE mode - plugins only]${NC}"
echo ""

# Determine if running from curl or locally.
# We're "local" when this script's sibling config/variables.sh is reachable — that's
# more robust than the `[ -t 0 ]` heuristic (which broke under pipes, redirects, CI).
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ -n "$_self_dir" ] && [ -f "${_self_dir}/config/variables.sh" ]; then
    SCRIPT_DIR="$_self_dir"
    LOCAL_MODE=true
else
    SCRIPT_DIR="/tmp/startup_installer_$$"
    LOCAL_MODE=false
    mkdir -p "$SCRIPT_DIR"
fi
unset _self_dir

# Function to source config files
source_config() {
    local config_file=$1
    if [ "$LOCAL_MODE" = true ]; then
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/config/${config_file}"
    else
        local url="${RAW_BASE_URL}/config/${config_file}"
        curl -fsSL "$url" -o "${SCRIPT_DIR}/${config_file}" || return 1
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/${config_file}"
    fi
}

# Set GitHub variables for remote execution
if [ "$LOCAL_MODE" = false ]; then
    export GITHUB_USER="${GITHUB_USER:-ranjithn}"
    export GITHUB_REPO="${GITHUB_REPO:-startup}"
    export GITHUB_REF="${GITHUB_REF:-${GITHUB_BRANCH:-master}}"
    export RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_REF}"
fi

# Load variables and utility functions
source_config "variables.sh" || exit 1

# Bootstrap Homebrew BEFORE package manager detection.
source_config "brew.sh" || exit 1
install_homebrew || exit 1

detect_package_manager || exit 1
check_sudo || exit 1

if [ "$UPDATE_ONLY" != true ]; then
    log_info "Updating Homebrew..."
    maybe_run brew update 2>/dev/null || log_warning "brew update had issues (continuing anyway)"
fi

# Load and run module installations
log_info "Loading installation modules..."

for module in vim.sh tmux.sh zsh.sh macos_defaults.sh ssh.sh; do
    source_config "$module" || exit 1
done

FAILED_STEPS=()
run_step() {
    local name=$1
    shift
    echo
    log_info "$name"
    if ! "$@"; then
        FAILED_STEPS+=("$name")
        log_error "$name failed"
    fi
}

run_step "Brewfile packages" install_brewfile
run_step "Vim" setup_vim
run_step "Tmux" setup_tmux
run_step "Zsh" setup_zsh
run_step "macOS defaults" setup_macos_defaults
run_step "SSH client key" setup_ssh

# Cleanup if running from curl
if [ "$LOCAL_MODE" = false ]; then
    rm -rf "$SCRIPT_DIR"
fi

# Final message
echo
if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    echo -e "${RED}======================================${NC}"
    echo -e "${RED}  Installation completed with errors${NC}"
    printf '  - %s\n' "${FAILED_STEPS[@]}"
    exit 1
fi

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Installation complete${NC}"
echo -e "${GREEN}======================================${NC}"

if [ "$UPDATE_ONLY" != true ]; then
    log_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. For Vim:   Run ':PlugInstall' inside vim if plugins didn't install"
    echo "  3. For Tmux:  Press 'prefix + I' (Ctrl+a then I) to install plugins"
    echo "  4. For Zsh:   Run 'p10k configure' to customize your prompt"
    echo "  5. Install Docker manually (Docker Desktop, OrbStack, Colima — your choice)"
    echo ""
    log_warning "Note: If your shell didn't change, run: chsh -s \$(which zsh)"
fi
echo ""
