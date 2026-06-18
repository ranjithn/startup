#!/bin/bash
# Linux VPS hardening — sensible defaults for fresh cloud machines accessed via SSH.
# Skips all functions on macOS. Risky changes (sshd_config) gated behind
# HARDEN_SSHD=true (set by the --harden-sshd flag).

_hardening_skip() {
    [ "${IS_MACOS:-false}" = true ]
}

set_timezone_utc() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0

    if ! command -v timedatectl &> /dev/null; then
        log_warning "timedatectl not available; skipping timezone setup"
        return 0
    fi

    local current
    current=$(timedatectl show --property=Timezone --value 2>/dev/null)
    if [ "$current" = "UTC" ]; then
        log_success "Timezone is already UTC"
    else
        log_info "Setting timezone to UTC..."
        maybe_run $SUDO timedatectl set-timezone UTC 2>/dev/null \
            || log_warning "could not set timezone"
    fi

    maybe_run $SUDO timedatectl set-ntp true 2>/dev/null \
        || log_warning "could not enable NTP"
    log_success "Time sync configured"
}

setup_swap_if_low_ram() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0

    # Skip when swap is already present
    if [ "$(swapon --show 2>/dev/null | wc -l)" -gt 0 ]; then
        log_success "swap already configured"
        return 0
    fi

    # Skip container-like environments (no permission to swapon)
    if [ -f /.dockerenv ] || grep -qE '^[0-9]+:[^:]*:.*/(docker|lxc|kubepods)' /proc/1/cgroup 2>/dev/null; then
        log_warning "container environment detected; skipping swap setup"
        return 0
    fi

    local ram_kb
    ram_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
    [ -z "$ram_kb" ] && return 0

    if [ "$ram_kb" -ge 2097152 ]; then
        log_success "RAM is $((ram_kb / 1024)) MB; no swap created"
        return 0
    fi

    log_info "Low RAM ($((ram_kb / 1024)) MB); creating 2G swap file..."
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would create /swapfile (2G), mkswap, swapon, append to /etc/fstab"
        return 0
    fi
    $SUDO fallocate -l 2G /swapfile 2>/dev/null \
        || $SUDO dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
    $SUDO chmod 600 /swapfile
    $SUDO mkswap /swapfile >/dev/null
    $SUDO swapon /swapfile
    if ! grep -q "^/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
    fi
    log_success "Created 2G swap at /swapfile"
}

install_unattended_upgrades() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0

    case "$PKG_MANAGER" in
        apt-get)
            if dpkg -s unattended-upgrades &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
                log_success "unattended-upgrades already installed"
            else
                log_info "Installing unattended-upgrades..."
                maybe_run $SUDO $PKG_INSTALL unattended-upgrades apt-listchanges \
                    || { log_warning "unattended-upgrades install failed"; return 0; }
            fi
            maybe_run $SUDO dpkg-reconfigure -plow -fnoninteractive unattended-upgrades 2>/dev/null \
                || log_warning "could not auto-configure unattended-upgrades"
            log_success "unattended-upgrades enabled"
            ;;
        dnf|yum)
            if rpm -q dnf-automatic &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
                log_success "dnf-automatic already installed"
            else
                log_info "Installing dnf-automatic..."
                maybe_run $SUDO $PKG_INSTALL dnf-automatic \
                    || { log_warning "dnf-automatic install failed"; return 0; }
            fi
            if command -v systemctl &>/dev/null; then
                maybe_run $SUDO systemctl enable --now dnf-automatic.timer 2>/dev/null \
                    || log_warning "could not enable dnf-automatic.timer"
            fi
            log_success "dnf-automatic enabled"
            ;;
        *)
            log_warning "auto security updates not configured for $PKG_MANAGER"
            ;;
    esac
}

install_ufw() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0

    if ! command -v ufw &>/dev/null; then
        log_info "Installing ufw..."
        maybe_run $SUDO $PKG_INSTALL ufw \
            || { log_warning "ufw install failed"; return 0; }
    else
        log_success "ufw already installed"
    fi

    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would set ufw defaults, allow OpenSSH, then enable ufw"
        return 0
    fi

    # CRITICAL: allow SSH BEFORE enabling — otherwise we lock ourselves out
    $SUDO ufw default deny incoming >/dev/null
    $SUDO ufw default allow outgoing >/dev/null
    $SUDO ufw allow OpenSSH >/dev/null 2>&1 || $SUDO ufw allow 22/tcp >/dev/null

    if $SUDO ufw status | grep -q "Status: active"; then
        log_success "ufw already active; SSH rule ensured"
    else
        $SUDO ufw --force enable >/dev/null
        log_success "ufw enabled with SSH allowed"
    fi
}

install_fail2ban() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0

    if command -v fail2ban-server &>/dev/null && [ "$FORCE_INSTALL" != true ]; then
        log_success "fail2ban already installed"
    else
        log_info "Installing fail2ban..."
        maybe_run $SUDO $PKG_INSTALL fail2ban \
            || { log_warning "fail2ban install failed"; return 0; }
    fi
    if command -v systemctl &>/dev/null; then
        maybe_run $SUDO systemctl enable --now fail2ban 2>/dev/null \
            || log_warning "could not enable fail2ban"
    fi
    log_success "fail2ban running"
}

harden_sshd() {
    [ "$UPDATE_ONLY" = true ] && return 0
    _hardening_skip && return 0
    [ "${HARDEN_SSHD:-false}" != true ] && return 0

    # Safety: refuse to disable password auth without a key already in place
    local auth_keys="${HOME}/.ssh/authorized_keys"
    local sudo_user_home
    sudo_user_home=$(eval echo "~${SUDO_USER:-$USER}")
    [ -s "${sudo_user_home}/.ssh/authorized_keys" ] || [ -s "$auth_keys" ] || {
        log_warning "no authorized_keys present; refusing to disable password auth (would lock you out)"
        log_warning "add your public key to ~/.ssh/authorized_keys and rerun with --harden-sshd"
        return 0
    }

    local sshd_conf="/etc/ssh/sshd_config.d/99-startup.conf"
    if [ "$DRY_RUN" = true ]; then
        log_dryrun "Would write $sshd_conf disabling root login + password auth"
        return 0
    fi
    $SUDO mkdir -p /etc/ssh/sshd_config.d
    $SUDO tee "$sshd_conf" >/dev/null <<'EOF'
# Managed by ranjithn/startup. To restore defaults, delete this file.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
EOF
    $SUDO systemctl reload sshd 2>/dev/null || $SUDO systemctl reload ssh 2>/dev/null \
        || log_warning "could not reload sshd (changes apply on next restart)"
    log_success "sshd hardened (root login + password auth disabled)"
}

setup_linux_hardening() {
    _hardening_skip && return 0
    set_timezone_utc
    setup_swap_if_low_ram
    install_unattended_upgrades
    install_ufw
    install_fail2ban
    harden_sshd
}
