#!/bin/bash
# Common variables and settings

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Installation directories
export DOTFILES_DIR="${HOME}/.dotfiles"
export BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# GitHub raw content base URL for fetching dotfiles (set only in remote mode by linux_installer.sh)
export GITHUB_USER="${GITHUB_USER:-ranjithn}"
export GITHUB_REPO="${GITHUB_REPO:-startup}"
export GITHUB_BRANCH="${GITHUB_BRANCH:-dev}"

# Package manager detection
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        export PKG_MANAGER="apt-get"
        export PKG_UPDATE="apt-get update"
        export PKG_INSTALL="apt-get install -y"
    elif command -v dnf &> /dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_UPDATE="dnf check-update || true"
        export PKG_INSTALL="dnf install -y"
    elif command -v yum &> /dev/null; then
        export PKG_MANAGER="yum"
        export PKG_UPDATE="yum check-update || true"
        export PKG_INSTALL="yum install -y"
    elif command -v pacman &> /dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_UPDATE="pacman -Sy"
        export PKG_INSTALL="pacman -S --noconfirm"
    else
        echo -e "${RED}Error: No supported package manager found${NC}"
        exit 1
    fi
}

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Backup existing file
backup_file() {
    local file=$1
    if [ -f "$file" ] || [ -L "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$file" "$BACKUP_DIR/"
        log_warning "Backed up existing $(basename $file) to $BACKUP_DIR"
    fi
}

# Check if running as root (for package installation)
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            log_error "This script requires sudo privileges. Please run as root or install sudo."
            exit 1
        fi
        export SUDO="sudo"
    else
        export SUDO=""
    fi
}
