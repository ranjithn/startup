#!/bin/bash
# Linux server development environment installer
#
# Usage:
#   Local:  bash linux_installer.sh [options]
#   Remote: curl -fsSL URL | bash -s -- [options]

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$(uname -s)" != Linux ]; then
    echo -e "${RED}Error: This installer is for Linux only.${NC}"
    exit 1
fi

FORCE_INSTALL=false
UPDATE_ONLY=false
DRY_RUN=false
PROFILE=server
WITH_DOCKER=false
DOCKER_GROUP=false
ENABLE_SSH=false
GENERATE_SSH_KEY=false

usage() {
    cat <<'EOF'
Usage: linux_installer.sh [options]

Options:
  --profile server|workstation  Select system policy (default: server)
  --with-docker                 Install Docker Engine
  --docker-group                Also add the current user to the root-equivalent docker group
  --enable-ssh                  Install/enable SSH, open its firewall rule, and harden when keys permit
  --generate-ssh-key            Interactively generate a passphrase-protected client SSH key if missing
  --force                       Reinstall packages/plugins and redeploy managed configuration
  --update                      Update user plugins only; skip packages and system configuration
  --dry-run                     Print actions without changing the machine
  -h, --help                    Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --profile)
            [ "$#" -ge 2 ] || { echo "--profile requires server or workstation" >&2; exit 2; }
            PROFILE=$2
            shift
            ;;
        --with-docker)      WITH_DOCKER=true ;;
        --docker-group)     WITH_DOCKER=true; DOCKER_GROUP=true ;;
        --enable-ssh)       ENABLE_SSH=true ;;
        --generate-ssh-key) GENERATE_SSH_KEY=true ;;
        --harden-sshd)
            echo "Warning: --harden-sshd is deprecated; using --enable-ssh" >&2
            ENABLE_SSH=true
            ;;
        --force)            FORCE_INSTALL=true ;;
        --update)           UPDATE_ONLY=true ;;
        --dry-run)          DRY_RUN=true ;;
        -h|--help)          usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "$PROFILE" in
    server|workstation) ;;
    *) echo "Invalid profile '$PROFILE'; expected server or workstation" >&2; exit 2 ;;
esac

export FORCE_INSTALL UPDATE_ONLY DRY_RUN PROFILE WITH_DOCKER DOCKER_GROUP ENABLE_SSH GENERATE_SSH_KEY

if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Do not run the installer with sudo; run it as your login user.${NC}" >&2
    echo "It invokes sudo only for the individual system operations that require it." >&2
    exit 1
fi

printf '%b\n' "${BLUE}======================================${NC}"
printf '%b\n' "${BLUE}  Linux Development Environment Setup${NC}"
printf '%b\n' "${BLUE}======================================${NC}"
echo "  Profile: $PROFILE"
[ "$DRY_RUN" = true ] && echo "  [DRY-RUN MODE — no changes will be made]"
[ "$FORCE_INSTALL" = true ] && echo "  [FORCE mode]"
[ "$UPDATE_ONLY" = true ] && echo "  [UPDATE mode — user plugins only]"
[ "$WITH_DOCKER" = true ] && echo "  [Docker enabled]"
[ "$ENABLE_SSH" = true ] && echo "  [SSH server enabled]"
echo

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ -n "$_self_dir" ] && [ -f "${_self_dir}/config/variables.sh" ]; then
    SCRIPT_DIR=$_self_dir
    LOCAL_MODE=true
else
    SCRIPT_DIR="/tmp/startup_installer_$$"
    LOCAL_MODE=false
    mkdir -p "$SCRIPT_DIR"
fi
unset _self_dir

cleanup() {
    if [ "${LOCAL_MODE:-true}" = false ] && [ -n "${SCRIPT_DIR:-}" ]; then
        rm -rf "$SCRIPT_DIR"
    fi
}
trap cleanup EXIT INT TERM

if [ "$LOCAL_MODE" = false ]; then
    export GITHUB_USER="${GITHUB_USER:-ranjithn}"
    export GITHUB_REPO="${GITHUB_REPO:-startup}"
    export GITHUB_REF="${GITHUB_REF:-${GITHUB_BRANCH:-master}}"
    export RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_REF}"
fi

source_config() {
    local config_file=$1
    if [ "$LOCAL_MODE" = true ]; then
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/config/${config_file}"
    else
        local url="${RAW_BASE_URL}/config/${config_file}"
        if ! curl -fsSL "$url" -o "${SCRIPT_DIR}/${config_file}"; then
            echo "Failed to download $url" >&2
            return 1
        fi
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/${config_file}"
    fi
}

source_config variables.sh || exit 1
detect_package_manager || exit 1

# Plugin-only updates are user-level. Dry-run also must not require sudo access.
if [ "$UPDATE_ONLY" = true ] || [ "$DRY_RUN" = true ]; then
    SUDO=$(command -v sudo 2>/dev/null || true)
    export SUDO
else
    check_sudo || exit 1
fi

if [ "$UPDATE_ONLY" != true ]; then
    log_info "Refreshing package metadata..."
    pkg_update || log_warning "Package metadata refresh had issues; package installs may fail"
fi

log_info "Loading installation modules..."
for module in packages.sh vim.sh tmux.sh zsh.sh docker.sh ssh.sh linux_hardening.sh; do
    source_config "$module" || exit 1
done

FAILED_STEPS=()
run_step() {
    local name=$1
    shift
    echo
    log_info "$name"
    if ! "$@"; then
        FAILED_STEPS+=("$name")
        log_error "$name failed"
    fi
}

run_step "Linux package baseline" setup_packages
run_step "Vim" setup_vim
run_step "Tmux" setup_tmux
run_step "Zsh" setup_zsh
run_step "Docker" setup_docker
run_step "SSH client key" setup_ssh
run_step "Linux system policy" setup_linux_hardening

echo
if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    printf '%b\n' "${RED}======================================${NC}"
    printf '%b\n' "${RED}  Installation completed with errors${NC}"
    printf '  - %s\n' "${FAILED_STEPS[@]}"
    exit 1
fi

printf '%b\n' "${GREEN}======================================${NC}"
printf '%b\n' "${GREEN}  Installation complete${NC}"
printf '%b\n' "${GREEN}======================================${NC}"
if [ "$UPDATE_ONLY" != true ]; then
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Run 'p10k configure' if you use Powerlevel10k glyphs"
    [ "$WITH_DOCKER" = true ] && [ "$DOCKER_GROUP" != true ] && \
        echo "  3. Docker requires sudo unless you explicitly rerun with --docker-group or configure rootless mode"
    [ "$GENERATE_SSH_KEY" != true ] && \
        echo "  4. Generate a client key later with --generate-ssh-key if needed"
fi
