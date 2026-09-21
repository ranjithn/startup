# Startup Scripts

Re-entrant setup scripts for a personal Ubuntu/Linux server and an Apple Silicon Mac. Linux defaults to a conservative **server** profile. Docker, an SSH server, and client SSH key generation are explicit opt-ins.

## Recommended Linux Setup

Clone and inspect the repository before running it:

```bash
git clone https://github.com/ranjithn/startup.git
cd startup
bash linux_installer.sh --dry-run
bash linux_installer.sh
```

For a server that should accept SSH connections:

```bash
bash linux_installer.sh --enable-ssh
```

`--enable-ssh` installs and starts OpenSSH, opens only its firewall service, enables fail2ban, and disables password/root login **only after** a non-empty `authorized_keys` is present. The generated sshd drop-in is checked with `sshd -t` before SSH is reloaded.

If the installer detects an active SSH session, it refuses to enable the firewall without `--enable-ssh` rather than risk locking you out.

### Linux options

| Option | Behavior |
|---|---|
| `--profile server` | Default. UTC/NTP, low-memory swap policy, unattended security updates, and firewall |
| `--profile workstation` | Package and firewall setup without changing timezone/swap or enabling unattended upgrades |
| `--enable-ssh` | Install/enable OpenSSH, permit it through the firewall, enable fail2ban, and harden when authorized keys permit |
| `--with-docker` | Install Docker Engine from the correct official Debian/Ubuntu/Fedora/CentOS-family repository |
| `--docker-group` | Also install Docker and add the user to the root-equivalent `docker` group |
| `--generate-ssh-key` | Interactively create a passphrase-protected Ed25519 client key when one does not exist |
| `--force` | Reinstall/redeploy managed components; existing SSH identity keys are still preserved |
| `--update` | Update user plugins only; do not change packages or system policy |
| `--dry-run` | Print intended commands without changing the machine |

Docker is disabled by default. Without `--docker-group`, use `sudo docker` or configure rootless Docker. Docker-published ports can bypass UFW expectations, so bind published services deliberately.

## Linux Packages

The distro-aware baseline includes:

- `curl`, CA certificates, and OpenSSH client tools
- Vim, tmux, and zsh
- ripgrep, fd, bat, eza, fzf, and jq
- unzip and rsync
- ShellCheck and shfmt
- compiler/build tooling

Unavailable packages are reported and skipped individually. Debian/Ubuntu command names such as `fdfind` and `batcat` receive user-local `fd` and `bat` symlinks.

Git, GitHub CLI, and Git LFS are intentionally not installed on Linux. Git-backed Vim, tmux, Oh My Zsh, and Zsh plugin installation is skipped with a warning when Git is absent; the base packages and dotfiles still install.

Supported package families are apt (Ubuntu/Debian), dnf/yum (Fedora and CentOS-compatible distributions), and pacman (Arch). Ubuntu is the primary target.

## macOS

Apple Silicon only:

```bash
bash macos_installer.sh --dry-run
bash macos_installer.sh
```

The macOS flow bootstraps Homebrew, applies the root `Brewfile`, deploys the same shell/editor configuration, and applies Finder/Dock/keyboard defaults. Docker remains a manual choice on macOS.

## Remote Bootstrap

Executing mutable `master` content directly is convenient but less safe than cloning and reviewing it. If remote bootstrap is necessary, pin both the entry script and downloaded modules to the same commit:

```bash
REF='<full-commit-sha>'
curl -fsSL "https://raw.githubusercontent.com/ranjithn/startup/$REF/linux_installer.sh" \
  | GITHUB_REF="$REF" bash -s -- --dry-run --enable-ssh
```

Remove `--dry-run` only after reviewing the output. A branch or tag also works as `GITHUB_REF`, but a full commit SHA is immutable.

## System Policy

### Firewall

- Ubuntu/Debian/Arch: UFW with default-deny incoming and allow outgoing.
- Fedora/CentOS family: firewalld.
- SSH is not opened unless `--enable-ssh` is supplied.
- Existing broad SSH allow rules are removed when SSH is not enabled.

### Server profile

- Sets UTC and enables network time synchronization.
- Creates a 2 GiB swap file only below 2 GiB RAM, when no swap exists and the host is not a container.
- Enables unattended security updates on apt/dnf systems.
- Leaves systems with at least 2 GiB RAM to their distribution's swap/zram policy.

### SSH identities

Client key generation is never implicit and `--force` never rotates an identity. `--generate-ssh-key` uses Ed25519 with strengthened key derivation and prompts for a passphrase.

## Managed Dotfiles

Managed files are deployed atomically:

- `~/.vimrc`
- `~/.tmux.conf`
- `~/.zshrc`

Their hashes are stored under `${XDG_STATE_HOME:-~/.local/state}/startup`. Unchanged managed files automatically receive repository updates. Locally modified files are backed up to `~/.dotfiles_backup_<timestamp>/` before the managed version is installed. Failed downloads leave the active file untouched.

Use `~/.zshrc.local` for machine-specific shell configuration that should not be replaced.

## Editor and Shell Notes

- Vim uses vim-plug and the maintained canonical `vim-polyglot/vim-polyglot` repository.
- The archived `nerdtree-git-plugin` is no longer installed.
- Modern commands retain their real names; `cat`, `find`, and `grep` are not replaced with incompatible aliases.
- Locale configuration preserves a valid system locale and does not force `LC_ALL`.
- Tmux uses OSC 52 clipboard support; no X11 or Wayland clipboard packages are installed.
- Failure to run `chsh` only prints manual instructions; the installer never appends an unconditional `exec zsh` to `.bashrc`.

## Updating

```bash
bash linux_installer.sh --update
```

This updates Vim, tmux, Oh My Zsh, and Zsh plugins when their Git checkouts and Git itself are available. Distribution package upgrades are intentionally left to the OS update policy rather than hidden behind this flag.

## Testing

```bash
bash test/test_reentrant.sh
```

The test uses an isolated temporary `HOME`. It verifies atomic/hash-managed deployment, local-edit backups, failed-download preservation, dry-run behavior, package command arrays, dnf's special update status, Docker distro mapping, and shell syntax.

## Project Structure

```text
startup/
├── linux_installer.sh
├── macos_installer.sh
├── Brewfile
├── config/
│   ├── variables.sh
│   ├── packages.sh
│   ├── vim.sh
│   ├── tmux.sh
│   ├── zsh.sh
│   ├── docker.sh
│   ├── ssh.sh
│   ├── linux_hardening.sh
│   ├── brew.sh
│   └── macos_defaults.sh
├── dotfiles/
└── test/test_reentrant.sh
```

## License

MIT
