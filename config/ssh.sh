#!/bin/bash
# SSH key bootstrap (cross-platform).
# Generates an ed25519 keypair if one is missing, fixes permissions, and prints
# the public key so it can be added to GitHub, cloud providers, etc.

SSH_DIR="${HOME}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"
SSH_PUB="${SSH_KEY}.pub"

generate_ssh_key() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Checking SSH key..."

    if [ -f "$SSH_KEY" ] && [ "$FORCE_INSTALL" != true ]; then
        log_success "SSH key already exists at $SSH_KEY"
    else
        if [ "$DRY_RUN" = true ]; then
            log_dryrun "Would generate ed25519 SSH key at $SSH_KEY"
            return 0
        fi
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        local label="$(whoami)@$(hostname -s 2>/dev/null || hostname)"
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$label" \
            || { log_error "ssh-keygen failed"; return 1; }
        log_success "Generated SSH key at $SSH_KEY"
    fi

    # Fix permissions defensively — common cause of "permissions are too open" errors
    if [ "$DRY_RUN" != true ]; then
        chmod 700 "$SSH_DIR" 2>/dev/null
        [ -f "$SSH_KEY" ] && chmod 600 "$SSH_KEY" 2>/dev/null
        [ -f "$SSH_PUB" ] && chmod 644 "$SSH_PUB" 2>/dev/null
        [ -f "${SSH_DIR}/authorized_keys" ] && chmod 600 "${SSH_DIR}/authorized_keys" 2>/dev/null
        [ -f "${SSH_DIR}/config" ] && chmod 600 "${SSH_DIR}/config" 2>/dev/null
    fi

    if [ -f "$SSH_PUB" ] && [ "$DRY_RUN" != true ]; then
        echo ""
        log_info "Public key (add to GitHub / cloud provider / authorized_keys):"
        echo "  $(cat "$SSH_PUB")"
        echo ""
    fi
}

setup_ssh() {
    generate_ssh_key
}
