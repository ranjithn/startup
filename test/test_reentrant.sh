#!/bin/bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
export XDG_STATE_HOME="$TEST_DIR/state"
export DRY_RUN=false
export FORCE_INSTALL=false
export UPDATE_ONLY=false
mkdir -p "$HOME" "$TEST_DIR/fixture/dotfiles" "$TEST_DIR/bin"
SCRIPT_DIR="$TEST_DIR/fixture"
export SCRIPT_DIR

# shellcheck disable=SC1091
source "$REPO_DIR/config/variables.sh"

assert_eq() {
    local expected=$1 actual=$2 message=$3
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

printf 'one\n' >"$SCRIPT_DIR/dotfiles/.sample"
deploy_dotfile .sample
assert_eq one "$(<"$HOME/.sample")" "fresh deployment"
assert_eq true "$DEPLOY_CHANGED" "fresh deployment change flag"

deploy_dotfile .sample
assert_eq false "$DEPLOY_CHANGED" "identical second deployment is re-entrant"

printf 'two\n' >"$SCRIPT_DIR/dotfiles/.sample"
deploy_dotfile .sample
assert_eq two "$(<"$HOME/.sample")" "unchanged managed file receives repository update"

printf 'local edit\n' >"$HOME/.sample"
printf 'three\n' >"$SCRIPT_DIR/dotfiles/.sample"
deploy_dotfile .sample
assert_eq three "$(<"$HOME/.sample")" "locally edited file is replaced by managed update"
assert_eq 'local edit' "$(<"$BACKUP_DIR/.sample")" "local edit is backed up"

before=$(hash_file "$HOME/.sample")
if deploy_dotfile .missing 2>/dev/null; then
    echo "FAIL: missing source unexpectedly deployed" >&2
    exit 1
fi
after=$(hash_file "$HOME/.sample")
assert_eq "$before" "$after" "failed source leaves existing files untouched"

DRY_RUN=true
printf 'four\n' >"$SCRIPT_DIR/dotfiles/.sample"
deploy_dotfile .sample >/dev/null
assert_eq three "$(<"$HOME/.sample")" "dry-run does not deploy"

# Verify package commands are not executed in dry-run mode.
cat >"$TEST_DIR/bin/apt-get" <<EOF
#!/bin/bash
touch "$TEST_DIR/apt-was-run"
EOF
chmod +x "$TEST_DIR/bin/apt-get"
PATH="$TEST_DIR/bin:$PATH"
PKG_MANAGER=apt-get
PKG_UPDATE_CMD=(apt-get update)
SUDO=""
pkg_update >/dev/null
[ ! -e "$TEST_DIR/apt-was-run" ] || { echo "FAIL: dry-run executed apt-get" >&2; exit 1; }

# dnf's status 100 means updates are available and must not be treated as failure.
DRY_RUN=false
cat >"$TEST_DIR/bin/dnf" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$TEST_DIR/dnf-args"
exit 100
EOF
chmod +x "$TEST_DIR/bin/dnf"
PKG_MANAGER=dnf
PKG_UPDATE_CMD=(dnf check-update)
pkg_update
assert_eq 'check-update' "$(<"$TEST_DIR/dnf-args")" "dnf command uses array arguments"

# Docker apt repositories must follow the detected distribution.
# shellcheck disable=SC1091
source "$REPO_DIR/config/docker.sh"
OS_ID=ubuntu
OS_ID_LIKE=debian
assert_eq ubuntu "$(_docker_apt_distribution)" "Ubuntu uses the Ubuntu Docker repository"
OS_ID=debian
assert_eq debian "$(_docker_apt_distribution)" "Debian uses the Debian Docker repository"

for script in "$REPO_DIR"/*.sh "$REPO_DIR"/config/*.sh "$REPO_DIR"/test/*.sh; do
    bash -n "$script"
done

printf 'PASS: deployment hashes, dry-run, command arrays, Docker distro mapping, and syntax\n'
