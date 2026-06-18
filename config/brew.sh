#!/bin/bash
# Homebrew bootstrap + Brewfile (macOS only, Apple Silicon)

# Apple Silicon Homebrew prefix — this repo does not target Intel Macs.
BREW_PREFIX="/opt/homebrew"
BREW_BIN="${BREW_PREFIX}/bin/brew"

install_homebrew() {
    [ "$UPDATE_ONLY" = true ] && return 0

    if command -v brew &> /dev/null || [ -x "$BREW_BIN" ]; then
        log_success "Homebrew is already installed"
    else
        log_info "Installing Homebrew (will prompt for sudo password)..."
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would run the official Homebrew install script"
        else
            NONINTERACTIVE=1 /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
                || { log_error "Homebrew install failed"; return 1; }
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
