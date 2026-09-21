#!/bin/bash
# Optional client SSH key generation. Existing identity keys are never replaced.

SSH_DIR="${HOME}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"
SSH_PUB="${SSH_KEY}.pub"

generate_ssh_key() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$GENERATE_SSH_KEY" = true ] || {
        log_success "SSH client key generation not requested (use --generate-ssh-key)"
        return 0
    }

    if [ -f "$SSH_KEY" ]; then
        log_success "Existing SSH key preserved at $SSH_KEY"
    elif [ "$DRY_RUN" = true ]; then
        log_dryrun "Would interactively generate a passphrase-protected Ed25519 key at $SSH_KEY"
        return 0
    else
        command -v ssh-keygen &>/dev/null || { log_error "ssh-keygen is not installed"; return 1; }
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        local label
        label="$(whoami)@$(hostname -s 2>/dev/null || hostname)"
        log_info "Generating an Ed25519 key. Enter a passphrase when prompted."
        ssh-keygen -t ed25519 -a 100 -f "$SSH_KEY" -C "$label" \
            || { log_error "ssh-keygen failed"; return 1; }
        log_success "Generated SSH key at $SSH_KEY"
    fi

    if [ "$DRY_RUN" != true ]; then
        chmod 700 "$SSH_DIR" 2>/dev/null || true
        [ -f "$SSH_KEY" ] && chmod 600 "$SSH_KEY" 2>/dev/null || true
        [ -f "$SSH_PUB" ] && chmod 644 "$SSH_PUB" 2>/dev/null || true
        [ -f "${SSH_DIR}/authorized_keys" ] && chmod 600 "${SSH_DIR}/authorized_keys" 2>/dev/null || true
        [ -f "${SSH_DIR}/config" ] && chmod 600 "${SSH_DIR}/config" 2>/dev/null || true
    fi

    if [ -f "$SSH_PUB" ] && [ "$DRY_RUN" != true ]; then
        echo
        log_info "Public key:"
        sed 's/^/  /' "$SSH_PUB"
        echo
    fi
}

setup_ssh() {
    generate_ssh_key
}
