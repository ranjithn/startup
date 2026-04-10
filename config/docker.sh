#!/bin/bash
# Docker installation and configuration

install_docker() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Installing Docker..."

    if command -v docker &> /dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Docker is already installed"
        return 0
    fi

    case "$PKG_MANAGER" in
        apt-get)
            if [ "$DRY_RUN" = true ]; then
                log_dryrun "Would install Docker CE via official apt repository"
            else
                maybe_run $SUDO $PKG_INSTALL ca-certificates gnupg lsb-release
                $SUDO install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                    | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                    | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
                $SUDO apt-get update
                $SUDO $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;
        dnf|yum)
            if [ "$DRY_RUN" = true ]; then
                log_dryrun "Would install Docker CE via official yum repository"
            else
                maybe_run $SUDO $PKG_INSTALL yum-utils
                $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                $SUDO $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
            ;;
        pacman)
            maybe_run $SUDO $PKG_INSTALL docker docker-compose
            ;;
        *)
            log_warning "Docker auto-install not supported for package manager: $PKG_MANAGER"
            log_warning "Please install Docker manually: https://docs.docker.com/engine/install/"
            return 1
            ;;
    esac

    log_success "Docker installed successfully"
}

configure_docker() {
    [ "$UPDATE_ONLY" = true ] && return 0
    log_info "Configuring Docker..."

    # Enable and start Docker service
    if command -v systemctl &> /dev/null; then
        maybe_run $SUDO systemctl enable docker
        maybe_run $SUDO systemctl start docker
        log_success "Docker service enabled and started"
    fi

    # Add current user to the docker group so docker commands work without sudo.
    # Prefer SUDO_USER (the real user when running under sudo) over $USER.
    local target_user="${SUDO_USER:-$USER}"

    if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
        log_success "User '$target_user' is already in the docker group"
    else
        log_info "Adding '$target_user' to the docker group..."
        maybe_run $SUDO usermod -aG docker "$target_user"
        log_success "Added '$target_user' to docker group"
        log_warning "Run 'newgrp docker' or log out/in for the group change to take effect"
    fi
}

setup_docker() {
    install_docker
    configure_docker
}
