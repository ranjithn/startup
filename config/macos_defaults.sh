#!/bin/bash
# macOS system defaults — Finder, keyboard, Dock, screenshots, etc.
# Re-entrant: skips after first apply unless --force is passed. This respects
# any per-key changes the user makes manually after the initial install.

MACOS_DEFAULTS_MARKER="${HOME}/.cache/startup-macos-defaults-applied"

apply_macos_defaults() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "${IS_MACOS:-false}" != true ] && return 0

    if [ -f "$MACOS_DEFAULTS_MARKER" ] && [ "$FORCE_INSTALL" != true ]; then
        log_success "macOS defaults already applied (delete $MACOS_DEFAULTS_MARKER or use --force to reapply)"
        return 0
    fi

    log_info "Applying macOS system defaults..."

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would apply keyboard, Finder, Dock, screenshots, and .DS_Store defaults"
        return 0
    fi

    # ---- Keyboard ----
    # Fast key repeat (vim-friendly)
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    # Disable press-and-hold accent picker so j/k/etc. auto-repeat in editors
    defaults write -g ApplePressAndHoldEnabled -bool false

    # ---- Finder ----
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    # Search the current folder by default (not whole Mac)
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

    # ---- Screenshots ----
    mkdir -p "${HOME}/Pictures/Screenshots"
    defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"
    defaults write com.apple.screencapture type -string "png"
    defaults write com.apple.screencapture disable-shadow -bool true

    # ---- Dock ----
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.5
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock mineffect -string "scale"

    # ---- Disable .DS_Store on network and USB volumes ----
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

    # Apply changes to running apps
    killall Finder Dock cfprefsd 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

    mkdir -p "$(dirname "$MACOS_DEFAULTS_MARKER")"
    touch "$MACOS_DEFAULTS_MARKER"
    log_success "macOS defaults applied"
    log_warning "Some changes (key repeat especially) need a logout/login to fully take effect"
}

setup_macos_defaults() {
    apply_macos_defaults
}
