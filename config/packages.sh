#!/bin/bash
# Distro-aware Linux server development package baseline.
# Git and GitHub tooling are intentionally not installed by this module.

_package_available() {
    local package=$1
    case "$PKG_MANAGER" in
        apt-get) apt-cache show "$package" &>/dev/null ;;
        dnf)     dnf -q list --available "$package" &>/dev/null || rpm -q "$package" &>/dev/null ;;
        yum)     yum -q list available "$package" &>/dev/null || rpm -q "$package" &>/dev/null ;;
        pacman)  pacman -Si "$package" &>/dev/null || pacman -Q "$package" &>/dev/null ;;
        *)       return 1 ;;
    esac
}

_install_available_packages() {
    local package
    local available=()
    for package in "$@"; do
        if [ "$DRY_RUN" = true ] || _package_available "$package"; then
            available+=("$package")
        else
            log_warning "Package '$package' is unavailable from configured $PKG_MANAGER repositories; skipping"
        fi
    done
    [ "${#available[@]}" -eq 0 ] || pkg_install "${available[@]}"
}

configure_debian_command_names() {
    [ "$DRY_RUN" = true ] && {
        log_dryrun "Would provide user-local 'fd' and 'bat' command names when only fdfind/batcat exist"
        return 0
    }

    mkdir -p "${HOME}/.local/bin"
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        ln -sfn "$(command -v fdfind)" "${HOME}/.local/bin/fd"
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sfn "$(command -v batcat)" "${HOME}/.local/bin/bat"
    fi
}

install_linux_packages() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "${IS_MACOS:-false}" = true ] && return 0

    log_info "Installing Linux server development packages..."
    local packages=()
    case "$PKG_MANAGER" in
        apt-get)
            packages=(
                ca-certificates curl openssh-client vim tmux zsh ripgrep fd-find bat eza fzf jq
                unzip rsync shellcheck shfmt build-essential
            )
            ;;
        dnf|yum)
            packages=(
                ca-certificates curl openssh-clients vim-enhanced tmux zsh ripgrep fd-find bat eza fzf jq
                unzip rsync ShellCheck shfmt gcc gcc-c++ make
            )
            ;;
        pacman)
            packages=(
                ca-certificates curl openssh vim tmux zsh ripgrep fd bat eza fzf jq
                unzip rsync shellcheck shfmt base-devel
            )
            ;;
        *)
            log_error "No Linux package mapping for $PKG_MANAGER"
            return 1
            ;;
    esac

    _install_available_packages "${packages[@]}" || return 1
    [ "$PKG_MANAGER" = apt-get ] && configure_debian_command_names
    log_success "Linux package baseline installed"
}

setup_packages() {
    install_linux_packages
}
