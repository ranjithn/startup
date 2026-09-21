#!/bin/bash
# Linux system policy. The server profile adds UTC, low-memory swap, and
# automatic security updates. A firewall is enabled for every profile. SSH and
# fail2ban are configured only with --enable-ssh.

set_timezone_utc() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$PROFILE" = server ] || return 0
    command -v timedatectl &>/dev/null || { log_warning "timedatectl unavailable; keeping current timezone"; return 0; }

    local current
    current=$(timedatectl show --property=Timezone --value 2>/dev/null || true)
    if [ "$current" = UTC ]; then
        log_success "Timezone is already UTC"
    else
        run_privileged timedatectl set-timezone UTC || return 1
    fi
    run_privileged timedatectl set-ntp true || log_warning "Could not enable network time synchronization"
}

setup_swap_if_low_ram() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$PROFILE" = server ] || return 0

    if [ "$(swapon --show 2>/dev/null | wc -l)" -gt 0 ]; then
        log_success "Swap is already configured"
        return 0
    fi
    if [ -f /.dockerenv ] || grep -qE '^[0-9]+:[^:]*:.*/(docker|lxc|kubepods)' /proc/1/cgroup 2>/dev/null; then
        log_warning "Container environment detected; skipping swap setup"
        return 0
    fi

    local ram_kb
    ram_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
    [ -n "$ram_kb" ] || return 0
    if [ "$ram_kb" -ge 2097152 ]; then
        log_success "RAM is $((ram_kb / 1024)) MB; leaving distro swap/zram policy unchanged"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would create and persist a 2 GiB /swapfile for this low-memory server"
        return 0
    fi
    [ ! -e /swapfile ] || { log_warning "/swapfile exists but is inactive; leaving it untouched"; return 0; }
    run_privileged fallocate -l 2G /swapfile \
        || run_privileged dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none \
        || return 1
    run_privileged chmod 600 /swapfile || return 1
    run_privileged mkswap /swapfile >/dev/null || return 1
    run_privileged swapon /swapfile || return 1
    if ! grep -q '^/swapfile[[:space:]]' /etc/fstab; then
        if [ -n "${SUDO:-}" ]; then
            printf '%s\n' '/swapfile none swap sw 0 0' | "$SUDO" tee -a /etc/fstab >/dev/null
        else
            printf '%s\n' '/swapfile none swap sw 0 0' >>/etc/fstab
        fi
    fi
    log_success "Created 2 GiB swap file"
}

install_unattended_upgrades() {
    [ "$UPDATE_ONLY" = true ] && return 0
    [ "$PROFILE" = server ] || return 0

    case "$PKG_MANAGER" in
        apt-get)
            pkg_install unattended-upgrades apt-listchanges || return 1
            run_privileged dpkg-reconfigure -plow -fnoninteractive unattended-upgrades \
                || log_warning "Could not automatically configure unattended-upgrades"
            ;;
        dnf|yum)
            pkg_install dnf-automatic || return 1
            if command -v systemctl &>/dev/null; then
                run_privileged systemctl enable --now dnf-automatic.timer || return 1
            fi
            ;;
        pacman)
            log_warning "Automatic upgrades are not enabled on Arch; use a deliberate pacman update schedule"
            ;;
    esac
}

configure_ufw() {
    pkg_install ufw || return 1
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would enable UFW with default-deny incoming; SSH rule: $ENABLE_SSH"
        return 0
    fi

    run_privileged ufw default deny incoming >/dev/null || return 1
    run_privileged ufw default allow outgoing >/dev/null || return 1
    if [ "$ENABLE_SSH" = true ]; then
        run_privileged ufw allow OpenSSH >/dev/null 2>&1 \
            || run_privileged ufw allow 22/tcp >/dev/null \
            || return 1
    else
        run_privileged ufw delete allow OpenSSH >/dev/null 2>&1 || true
        run_privileged ufw delete allow 22/tcp >/dev/null 2>&1 || true
    fi
    run_privileged ufw --force enable >/dev/null || return 1
    log_success "UFW enabled"
}

configure_firewalld() {
    pkg_install firewalld || return 1
    run_privileged systemctl enable --now firewalld || return 1
    if [ "$ENABLE_SSH" = true ]; then
        run_privileged firewall-cmd --permanent --add-service=ssh >/dev/null || return 1
    else
        run_privileged firewall-cmd --permanent --remove-service=ssh >/dev/null || true
    fi
    run_privileged firewall-cmd --reload >/dev/null || return 1
    log_success "firewalld enabled"
}

install_firewall() {
    [ "$UPDATE_ONLY" = true ] && return 0
    if [ "$DRY_RUN" != true ] && [ -n "${SSH_CONNECTION:-}" ] && [ "$ENABLE_SSH" != true ]; then
        log_error "Refusing to enable a firewall without an SSH rule during an active SSH session"
        log_error "Rerun with --enable-ssh after confirming how you want this server reached"
        return 1
    fi
    case "$PKG_MANAGER" in
        dnf|yum) configure_firewalld ;;
        apt-get|pacman) configure_ufw ;;
        *) log_error "No firewall policy for $PKG_MANAGER"; return 1 ;;
    esac
}

install_ssh_server() {
    [ "$ENABLE_SSH" = true ] || return 0
    local package service
    case "$PKG_MANAGER" in
        apt-get) package=openssh-server; service=ssh ;;
        dnf|yum) package=openssh-server; service=sshd ;;
        pacman) package=openssh; service=sshd ;;
        *) return 1 ;;
    esac
    pkg_install "$package" || return 1
    if command -v systemctl &>/dev/null; then
        run_privileged systemctl enable --now "$service" || return 1
    fi
}

install_fail2ban() {
    [ "$ENABLE_SSH" = true ] || return 0
    pkg_install fail2ban || return 1

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would enable the fail2ban sshd jail"
        return 0
    fi
    local jail_tmp
    jail_tmp=$(mktemp) || return 1
    cat >"$jail_tmp" <<'EOF'
# Managed by ranjithn/startup
[sshd]
enabled = true
EOF
    run_privileged install -m 0644 "$jail_tmp" /etc/fail2ban/jail.d/startup-sshd.local || return 1
    rm -f "$jail_tmp"
    if command -v systemctl &>/dev/null; then
        run_privileged systemctl enable --now fail2ban || return 1
    fi
}

_target_home() {
    local target_user="${SUDO_USER:-${USER:-}}"
    getent passwd "$target_user" 2>/dev/null | awk -F: '{print $6}'
}

harden_sshd() {
    [ "$ENABLE_SSH" = true ] || return 0

    local target_home auth_keys sshd_conf config_tmp backup_tmp
    target_home=$(_target_home)
    auth_keys="${target_home:-$HOME}/.ssh/authorized_keys"
    if [ ! -s "$auth_keys" ]; then
        log_warning "No authorized_keys found at $auth_keys; leaving SSH password authentication enabled"
        log_warning "Add and test a public key, then rerun with --enable-ssh"
        return 0
    fi

    sshd_conf=/etc/ssh/sshd_config.d/00-startup.conf
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would install $sshd_conf, validate with sshd -t, then reload SSH"
        return 0
    fi

    config_tmp=$(mktemp) || return 1
    backup_tmp=$(mktemp) || { rm -f "$config_tmp"; return 1; }
    cat >"$config_tmp" <<'EOF'
# Managed by ranjithn/startup. Delete this file to restore distribution defaults.
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
EOF
    run_privileged mkdir -p /etc/ssh/sshd_config.d || return 1
    if [ -f "$sshd_conf" ]; then
        if [ -n "${SUDO:-}" ]; then
            "$SUDO" cp "$sshd_conf" "$backup_tmp"
        else
            cp "$sshd_conf" "$backup_tmp"
        fi
    else
        : >"$backup_tmp"
    fi
    run_privileged install -m 0644 "$config_tmp" "$sshd_conf" || return 1
    rm -f "$config_tmp"

    if ! run_privileged sshd -t; then
        log_error "sshd validation failed; restoring the previous configuration"
        if [ -s "$backup_tmp" ]; then
            run_privileged install -m 0644 "$backup_tmp" "$sshd_conf"
        else
            run_privileged rm -f "$sshd_conf"
        fi
        rm -f "$backup_tmp"
        return 1
    fi

    local effective_config
    if [ -n "${SUDO:-}" ]; then
        effective_config=$("$SUDO" sshd -T 2>/dev/null) || effective_config=""
    else
        effective_config=$(sshd -T 2>/dev/null) || effective_config=""
    fi
    if ! grep -qx 'passwordauthentication no' <<<"$effective_config" \
        || ! grep -qx 'permitrootlogin no' <<<"$effective_config"; then
        log_error "The sshd drop-in is not effective; restoring the previous configuration"
        if [ -s "$backup_tmp" ]; then
            run_privileged install -m 0644 "$backup_tmp" "$sshd_conf"
        else
            run_privileged rm -f "$sshd_conf"
        fi
        rm -f "$backup_tmp"
        return 1
    fi
    rm -f "$backup_tmp"
    run_privileged systemctl reload sshd 2>/dev/null \
        || run_privileged systemctl reload ssh 2>/dev/null \
        || { log_error "Could not reload SSH"; return 1; }
    log_success "SSH hardened after successful configuration validation"
}

setup_linux_hardening() {
    set_timezone_utc || return 1
    setup_swap_if_low_ram || return 1
    install_unattended_upgrades || return 1
    install_firewall || return 1
    install_ssh_server || return 1
    install_fail2ban || return 1
    harden_sshd || return 1
    if [ "$WITH_DOCKER" = true ]; then
        log_warning "Docker-published ports may bypass UFW rules; bind services deliberately"
    fi
}
