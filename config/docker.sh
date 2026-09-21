#!/bin/bash
# Optional Docker Engine installation. Disabled unless --with-docker is used.

_docker_apt_distribution() {
    case "$OS_ID" in
        ubuntu) printf 'ubuntu\n' ;;
        debian) printf 'debian\n' ;;
        *)
            case " $OS_ID_LIKE " in
                *" ubuntu "*) printf 'ubuntu\n' ;;
                *" debian "*) printf 'debian\n' ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

install_docker_apt() {
    local distro codename arch key_tmp source_tmp
    distro=$(_docker_apt_distribution) || {
        log_error "Docker's apt repository is not mapped for distribution '$OS_ID'"
        return 1
    }
    codename=$OS_CODENAME
    [ "$distro" = ubuntu ] && [ -n "${OS_UBUNTU_CODENAME:-}" ] && codename=$OS_UBUNTU_CODENAME
    [ -n "$codename" ] || { log_error "Cannot determine distribution codename for Docker"; return 1; }
    arch=$(dpkg --print-architecture)

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would configure Docker's official $distro repository for $codename/$arch"
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        return
    fi

    pkg_install ca-certificates curl || return 1
    key_tmp=$(mktemp) || return 1
    source_tmp=$(mktemp) || { rm -f "$key_tmp"; return 1; }
    if ! curl -fsSL "https://download.docker.com/linux/${distro}/gpg" -o "$key_tmp"; then
        rm -f "$key_tmp" "$source_tmp"
        log_error "Failed to download Docker repository key"
        return 1
    fi
    cat >"$source_tmp" <<EOF
Types: deb
URIs: https://download.docker.com/linux/${distro}
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    run_privileged install -m 0755 -d /etc/apt/keyrings || return 1
    run_privileged install -m 0644 "$key_tmp" /etc/apt/keyrings/docker.asc || return 1
    run_privileged install -m 0644 "$source_tmp" /etc/apt/sources.list.d/docker.sources || return 1
    rm -f "$key_tmp" "$source_tmp"
    pkg_update || return 1
    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rpm() {
    local repo_family repo_tmp
    case "$OS_ID" in
        fedora) repo_family=fedora ;;
        rhel) repo_family=rhel ;;
        centos|rocky|almalinux) repo_family=centos ;;
        *)
            case " $OS_ID_LIKE " in
                *" centos "*) repo_family=centos ;;
                *" rhel "*) repo_family=rhel ;;
                *" fedora "*) repo_family=fedora ;;
                *) log_error "Docker's RPM repository is not mapped for '$OS_ID'"; return 1 ;;
            esac
            ;;
    esac

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would configure Docker's official $repo_family RPM repository"
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        return
    fi

    repo_tmp=$(mktemp) || return 1
    if ! curl -fsSL "https://download.docker.com/linux/${repo_family}/docker-ce.repo" -o "$repo_tmp"; then
        rm -f "$repo_tmp"
        log_error "Failed to download Docker RPM repository configuration"
        return 1
    fi
    run_privileged install -m 0644 "$repo_tmp" /etc/yum.repos.d/docker-ce.repo || return 1
    rm -f "$repo_tmp"
    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$WITH_DOCKER" = true ] || {
        log_success "Docker installation not requested (use --with-docker)"
        return 0
    }

    if command -v docker &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "Docker is already installed"
        return 0
    fi

    log_info "Installing Docker Engine..."
    case "$PKG_MANAGER" in
        apt-get) install_docker_apt ;;
        dnf|yum) install_docker_rpm ;;
        pacman)  pkg_install docker docker-compose ;;
        *)       log_error "Docker installation is unsupported for $PKG_MANAGER"; return 1 ;;
    esac
}

configure_docker() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$WITH_DOCKER" = true ] || return 0

    if command -v systemctl &>/dev/null; then
        run_privileged systemctl enable --now docker \
            || { log_error "Could not enable/start Docker"; return 1; }
    fi

    if [ "$DOCKER_GROUP" != true ]; then
        log_warning "The docker group grants root-equivalent access; it was not assigned"
        log_info "Use sudo, configure rootless Docker, or explicitly use --docker-group"
        return 0
    fi

    local target_user="${SUDO_USER:-${USER:-}}"
    [ -n "$target_user" ] || { log_error "Cannot determine user for docker group"; return 1; }
    if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
        log_success "User '$target_user' is already in the docker group"
    else
        run_privileged usermod -aG docker "$target_user" || return 1
        log_warning "Added '$target_user' to the root-equivalent docker group; log out/in before use"
    fi
}

setup_docker() {
    install_docker || return 1
    configure_docker
}
