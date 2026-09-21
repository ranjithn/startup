#!/bin/bash
# Common variables and settings

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Installation and state directories
export DOTFILES_DIR="${HOME}/.dotfiles"
BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
export BACKUP_DIR
export STARTUP_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/startup"

# GitHub raw content location for remote execution. GITHUB_REF may be a branch,
# tag, or immutable commit SHA.
export GITHUB_USER="${GITHUB_USER:-ranjithn}"
export GITHUB_REPO="${GITHUB_REPO:-startup}"
export GITHUB_REF="${GITHUB_REF:-${GITHUB_BRANCH:-master}}"

# Flags set by the entry scripts; defaults keep modules safe when sourced alone.
export FORCE_INSTALL="${FORCE_INSTALL:-false}"
export UPDATE_ONLY="${UPDATE_ONLY:-false}"
export DRY_RUN="${DRY_RUN:-false}"
export PROFILE="${PROFILE:-server}"
export WITH_DOCKER="${WITH_DOCKER:-false}"
export DOCKER_GROUP="${DOCKER_GROUP:-false}"
export ENABLE_SSH="${ENABLE_SSH:-false}"
export GENERATE_SSH_KEY="${GENERATE_SSH_KEY:-false}"

# Populated by detect_package_manager.
PKG_UPDATE_CMD=()
PKG_INSTALL_CMD=()

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_dryrun() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Run a command, or just print it in dry-run mode.
maybe_run() {
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would run: $(printf '%q ' "$@")"
    else
        "$@"
    fi
}

# Run a command with sudo when required.
run_privileged() {
    if [ -n "${SUDO:-}" ]; then
        maybe_run "$SUDO" "$@"
    else
        maybe_run "$@"
    fi
}

# Detect Linux distribution metadata used by package and Docker modules.
detect_linux_distribution() {
    export OS_ID=""
    export OS_ID_LIKE=""
    export OS_CODENAME=""
    export OS_UBUNTU_CODENAME=""

    [ "$(uname -s)" = Linux ] || return 0
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        export OS_ID="${ID:-}"
        export OS_ID_LIKE="${ID_LIKE:-}"
        export OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
        export OS_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
    fi
}

# Package manager detection. Commands are arrays so operators such as "||"
# can never accidentally become command arguments.
detect_package_manager() {
    detect_linux_distribution

    if [ "$(uname -s)" = Darwin ]; then
        export PKG_MANAGER="brew"
        export IS_MACOS=true
        PKG_UPDATE_CMD=(brew update)
        PKG_INSTALL_CMD=(brew install)
    elif command -v apt-get &>/dev/null; then
        export PKG_MANAGER="apt-get"
        export IS_MACOS=false
        PKG_UPDATE_CMD=(apt-get update)
        PKG_INSTALL_CMD=(apt-get install -y)
    elif command -v dnf &>/dev/null; then
        export PKG_MANAGER="dnf"
        export IS_MACOS=false
        PKG_UPDATE_CMD=(dnf check-update)
        PKG_INSTALL_CMD=(dnf install -y)
    elif command -v yum &>/dev/null; then
        export PKG_MANAGER="yum"
        export IS_MACOS=false
        PKG_UPDATE_CMD=(yum check-update)
        PKG_INSTALL_CMD=(yum install -y)
    elif command -v pacman &>/dev/null; then
        export PKG_MANAGER="pacman"
        export IS_MACOS=false
        PKG_UPDATE_CMD=(pacman -Sy)
        PKG_INSTALL_CMD=(pacman -S --needed --noconfirm)
    else
        log_error "No supported package manager found"
        return 1
    fi
}

pkg_update() {
    local status=0
    if [ -n "${SUDO:-}" ]; then
        maybe_run "$SUDO" "${PKG_UPDATE_CMD[@]}" || status=$?
    else
        maybe_run "${PKG_UPDATE_CMD[@]}" || status=$?
    fi

    # dnf/yum use 100 to mean that updates are available.
    if { [ "$PKG_MANAGER" = dnf ] || [ "$PKG_MANAGER" = yum ]; } && [ "$status" -eq 100 ]; then
        return 0
    fi
    return "$status"
}

pkg_install() {
    if [ -n "${SUDO:-}" ]; then
        maybe_run "$SUDO" "${PKG_INSTALL_CMD[@]}" "$@"
    else
        maybe_run "${PKG_INSTALL_CMD[@]}" "$@"
    fi
}

# Check if running as root. Homebrew must not be run as root.
check_sudo() {
    if [ "${IS_MACOS:-false}" = true ]; then
        export SUDO=""
    elif [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &>/dev/null; then
            log_error "This script requires sudo privileges. Install sudo or run it as root."
            return 1
        fi
        export SUDO="sudo"
    else
        export SUDO=""
    fi
}

hash_file() {
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        cksum "$1" | awk '{print $1 ":" $2}'
    fi
}

# Backup an existing file or symlink (no-op in dry-run mode).
backup_file() {
    local file=$1
    if [ -f "$file" ] || [ -L "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would back up $(basename "$file") to $BACKUP_DIR"
        else
            mkdir -p "$BACKUP_DIR"
            cp -pP "$file" "$BACKUP_DIR/"
            log_warning "Backed up existing $(basename "$file") to $BACKUP_DIR"
        fi
    fi
}

# Deploy a dotfile atomically and remember the deployed content hash.
# Unchanged managed files update automatically. Locally modified files are
# backed up before replacement. DEPLOY_CHANGED is set for callers.
deploy_dotfile() {
    local filename=$1
    local dest=${2:-${HOME}/${filename}}
    local source_tmp dest_tmp state_key state_file new_hash dest_hash previous_hash
    export DEPLOY_CHANGED=false

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would compare and deploy $filename to $dest atomically"
        return 0
    fi

    source_tmp=$(mktemp "${TMPDIR:-/tmp}/startup-dotfile.XXXXXX") || return 1
    if [ -n "${RAW_BASE_URL:-}" ]; then
        if ! curl -fsSL "${RAW_BASE_URL}/dotfiles/${filename}" -o "$source_tmp"; then
            rm -f "$source_tmp"
            log_error "Failed to download $filename; existing file was left untouched"
            return 1
        fi
    elif [ -n "${SCRIPT_DIR:-}" ] && [ -f "${SCRIPT_DIR}/dotfiles/${filename}" ]; then
        if ! cp "${SCRIPT_DIR}/dotfiles/${filename}" "$source_tmp"; then
            rm -f "$source_tmp"
            log_error "Failed to stage $filename; existing file was left untouched"
            return 1
        fi
    else
        rm -f "$source_tmp"
        log_error "Cannot find $filename — neither RAW_BASE_URL nor local dotfiles/ is available"
        return 1
    fi

    new_hash=$(hash_file "$source_tmp") || { rm -f "$source_tmp"; return 1; }
    state_key=$(printf '%s' "$dest" | tr '/ :' '___')
    state_file="${STARTUP_STATE_DIR}/dotfiles/${state_key}.sha256"
    previous_hash=""
    [ -f "$state_file" ] && previous_hash=$(<"$state_file")

    if [ -f "$dest" ]; then
        dest_hash=$(hash_file "$dest") || dest_hash=""
        if [ "$dest_hash" = "$new_hash" ]; then
            mkdir -p "$(dirname "$state_file")"
            printf '%s\n' "$new_hash" >"$state_file"
            rm -f "$source_tmp"
            log_success "$(basename "$dest") is already current"
            return 0
        fi
        if [ -n "$previous_hash" ] && [ "$dest_hash" != "$previous_hash" ]; then
            log_warning "$(basename "$dest") has local changes; preserving a backup before updating"
        fi
    fi

    mkdir -p "$(dirname "$dest")" "$(dirname "$state_file")"
    dest_tmp=$(mktemp "${dest}.tmp.XXXXXX") || { rm -f "$source_tmp"; return 1; }
    if ! cp "$source_tmp" "$dest_tmp"; then
        rm -f "$source_tmp" "$dest_tmp"
        return 1
    fi
    chmod 600 "$dest_tmp"
    rm -f "$source_tmp"

    backup_file "$dest"
    if ! mv "$dest_tmp" "$dest"; then
        rm -f "$dest_tmp"
        log_error "Failed to install $filename"
        return 1
    fi
    printf '%s\n' "$new_hash" >"$state_file"
    export DEPLOY_CHANGED=true
    log_success "Deployed $filename to $dest"
}
