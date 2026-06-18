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

# GitHub raw content base URL for fetching dotfiles (set only in remote mode by the installer entry scripts)
export GITHUB_USER="${GITHUB_USER:-ranjithn}"
export GITHUB_REPO="${GITHUB_REPO:-startup}"
export GITHUB_BRANCH="${GITHUB_BRANCH:-master}"

# Flags (exported by linux_installer.sh after arg parsing; default to false)
export FORCE_INSTALL="${FORCE_INSTALL:-false}"
export UPDATE_ONLY="${UPDATE_ONLY:-false}"
export DRY_RUN="${DRY_RUN:-false}"

# Package manager detection.
# On macOS, brew is assumed to be present (install_homebrew in config/brew.sh handles bootstrap).
# Detection here does NOT bail on missing brew so --dry-run still works on a fresh Mac.
detect_package_manager() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        export PKG_MANAGER="brew"
        export PKG_UPDATE="brew update"
        export PKG_INSTALL="brew install"
        export IS_MACOS=true
    elif command -v apt-get &> /dev/null; then
        export PKG_MANAGER="apt-get"
        export PKG_UPDATE="apt-get update"
        export PKG_INSTALL="apt-get install -y"
        export IS_MACOS=false
    elif command -v dnf &> /dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_UPDATE="dnf check-update || true"
        export PKG_INSTALL="dnf install -y"
        export IS_MACOS=false
    elif command -v yum &> /dev/null; then
        export PKG_MANAGER="yum"
        export PKG_UPDATE="yum check-update || true"
        export PKG_INSTALL="yum install -y"
        export IS_MACOS=false
    elif command -v pacman &> /dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_UPDATE="pacman -Sy"
        export PKG_INSTALL="pacman -S --noconfirm"
        export IS_MACOS=false
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

log_dryrun() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Run a command, or just print it in dry-run mode
maybe_run() {
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would run: $*"
    else
        "$@"
    fi
}

# Backup existing file (no-op in dry-run mode)
backup_file() {
    local file=$1
    if [ -f "$file" ] || [ -L "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would backup $(basename "$file") to $BACKUP_DIR"
        else
            mkdir -p "$BACKUP_DIR"
            mv "$file" "$BACKUP_DIR/"
            log_warning "Backed up existing $(basename "$file") to $BACKUP_DIR"
        fi
    fi
}

# Deploy a dotfile from the local clone (SCRIPT_DIR/dotfiles) or remote RAW_BASE_URL.
# Args: $1 = filename relative to dotfiles/ (e.g. ".vimrc")
#       $2 = destination path (default: $HOME/$1)
deploy_dotfile() {
    local filename=$1
    local dest=${2:-${HOME}/${filename}}
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would deploy $filename to $dest"
        return 0
    fi
    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    if [ -n "$RAW_BASE_URL" ]; then
        curl -fsSL "${RAW_BASE_URL}/dotfiles/${filename}" -o "$dest" \
            || { log_error "Failed to download $filename"; return 1; }
    elif [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/dotfiles/${filename}" ]; then
        cp "${SCRIPT_DIR}/dotfiles/${filename}" "$dest" \
            || { log_error "Failed to copy $filename"; return 1; }
    else
        log_error "Cannot find $filename — neither RAW_BASE_URL nor local dotfiles/ is available"
        return 1
    fi
}

# Check if running as root (for package installation)
# On macOS with Homebrew, sudo is not used for package installs.
check_sudo() {
    if [ "${IS_MACOS:-false}" = true ]; then
        # Homebrew must not be run as root; no sudo needed for brew commands
        export SUDO=""
    elif [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            log_error "This script requires sudo privileges. Please run as root or install sudo."
            exit 1
        fi
        export SUDO="sudo"
    else
        export SUDO=""
    fi
}
