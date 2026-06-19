#!/bin/bash
# Homebrew bootstrap + Brewfile (macOS only, Apple Silicon)

# Apple Silicon Homebrew prefix — this repo does not target Intel Macs.
BREW_PREFIX="/opt/homebrew"
BREW_BIN="${BREW_PREFIX}/bin/brew"

# Prime sudo for the Homebrew installer.
#
# Homebrew needs root to create /opt/homebrew, but we run its installer with
# NONINTERACTIVE=1 (required so `curl ... | bash` doesn't hang on Homebrew's own
# "Press RETURN to continue" prompt, which can't read from a piped stdin). In
# that mode Homebrew probes with `sudo -n` and aborts ("Need sudo access on
# macOS") if no credential is cached, instead of prompting. So we prompt here
# first: `sudo` reads from /dev/tty, so this works both locally and under
# curl-pipe. A background refresher keeps the credential alive because the
# install runs longer than sudo's default ~5-minute timeout.
prime_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_info "Homebrew needs administrator access — you'll be prompted for your password once."
        sudo -v || return 1
    fi
    ( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
    [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    unset SUDO_KEEPALIVE_PID
}

install_homebrew() {
    [ "$UPDATE_ONLY" = true ] && return 0

    if command -v brew &> /dev/null || [ -x "$BREW_BIN" ]; then
        log_success "Homebrew is already installed"
    else
        log_info "Installing Homebrew..."
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would run the official Homebrew install script"
        else
            prime_sudo || { log_error "Homebrew needs administrator access to install"; return 1; }
            NONINTERACTIVE=1 /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
                || { stop_sudo_keepalive; log_error "Homebrew install failed"; return 1; }
            stop_sudo_keepalive
        fi
    fi

    # Make brew available for the rest of this invocation
    if [ -x "$BREW_BIN" ] && ! command -v brew &> /dev/null; then
        eval "$($BREW_BIN shellenv)"
    fi
}

install_brewfile() {
    [ "$UPDATE_ONLY" = true ] && return 0

    local brewfile
    if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/Brewfile" ]; then
        brewfile="${SCRIPT_DIR}/Brewfile"
    elif [ -n "$RAW_BASE_URL" ]; then
        brewfile="${SCRIPT_DIR}/Brewfile"
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would download Brewfile from $RAW_BASE_URL"
        else
            curl -fsSL "${RAW_BASE_URL}/Brewfile" -o "$brewfile" \
                || { log_warning "Failed to download Brewfile; skipping bundle install"; return 0; }
        fi
    else
        log_warning "No Brewfile found; skipping bundle install"
        return 0
    fi

    log_info "Installing Brewfile packages..."
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would run: brew bundle install --file=$brewfile"
    else
        brew bundle install --file="$brewfile" \
            || log_warning "Some Brewfile entries failed to install (continuing)"
        log_success "Brewfile install complete"
    fi
}

setup_brew() {
    install_homebrew
    install_brewfile
}
