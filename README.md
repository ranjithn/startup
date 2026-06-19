# Startup Scripts

Modular installer scripts for setting up a development environment on a fresh machine. Two flows:

- **macOS** — typically used when reinstalling your own Mac. Bootstraps Homebrew, installs packages from a `Brewfile`, applies `defaults write` for keyboard / Finder / Dock / screenshots, generates an SSH key.
- **Linux** — typically used when provisioning a fresh cloud VPS that you'll access via SSH. Installs the same dev tools, hardens the host (timezone, swap, unattended-upgrades, ufw, fail2ban), and optionally locks down `sshd`.

Both flows share the same modular config under `config/` and the same dotfiles under `dotfiles/`.

## Quick Start

```bash
# macOS (fresh Apple Silicon Mac — bootstraps Homebrew automatically)
curl -fsSL https://raw.githubusercontent.com/ranjithn/startup/refs/heads/master/macos_installer.sh | bash

# Linux (cloud VPS via SSH)
curl -fsSL https://raw.githubusercontent.com/ranjithn/startup/refs/heads/master/linux_installer.sh | bash

# Local (after cloning)
git clone https://github.com/ranjithn/startup.git && cd startup
bash macos_installer.sh    # or linux_installer.sh
```

## CLI Flags

| Flag             | What it does                                                                                                |
|------------------|-------------------------------------------------------------------------------------------------------------|
| `--force`        | Reinstall everything, even if already present                                                              |
| `--update`       | Update plugins only (`git pull` + `PlugUpdate`/TPM update); skips package installs and config deployment    |
| `--dry-run`      | Print what would be done without making any changes                                                         |
| `--harden-sshd`  | **(Linux only)** Disable root login and password authentication in `sshd_config`. Refuses to run if `~/.ssh/authorized_keys` is empty — protects against locking yourself out. |

```bash
bash linux_installer.sh --dry-run            # preview changes
bash macos_installer.sh --update             # pull latest plugin updates
bash linux_installer.sh --force              # full reinstall
bash linux_installer.sh --harden-sshd        # opt into sshd hardening
```

## What Gets Installed

### Shared (macOS + Linux)
- **Vim** with vim-plug, NERDTree, vim-airline, vim-fugitive, vim-gitgutter, gruvbox, FZF, polyglot
- **Tmux** with TPM, tmux-resurrect, tmux-continuum, tmux-yank, tmux-pain-control, true-color (`tmux-256color`)
- **Zsh** with Oh My Zsh, Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions
- **SSH key** — generates `~/.ssh/id_ed25519` if one is missing, fixes permissions, prints the public key for adding to GitHub / cloud providers / `authorized_keys`

### macOS-only

#### Homebrew bootstrap
- Installs Homebrew at `/opt/homebrew` (Apple Silicon only — this repo does not target Intel Macs).
- Wires `eval "$(/opt/homebrew/bin/brew shellenv)"` into `.zshrc`.

#### Brewfile (declarative package list)
The `Brewfile` at the repo root holds the package set. Edit it freely; the installer runs `brew bundle install --file=Brewfile`. Defaults: git, curl, vim, tmux, zsh, and the MesloLGS Nerd Font (for Powerlevel10k icons).

Docker is intentionally not managed here — install Docker Desktop, OrbStack, or Colima yourself based on your use case and licensing constraints.

#### macOS system defaults (`config/macos_defaults.sh`)
First-run only (re-entrant via marker `~/.cache/startup-macos-defaults-applied`; `--force` reapplies):
- **Keyboard**: fast key repeat (`KeyRepeat=2`, `InitialKeyRepeat=15`), disable press-and-hold accent picker
- **Finder**: show all files, show extensions, path bar + status bar, POSIX path in title bar, search current folder
- **Screenshots**: saved to `~/Pictures/Screenshots` as PNG, no shadow
- **Dock**: autohide with no delay, hide recents, scale minimize effect
- **No `.DS_Store`** on network or USB volumes

> ⚠️ Some changes (key repeat especially) need a logout/login to take effect fully.

### Linux-only

#### Docker CE
- Installs Docker CE via the official repo (apt, dnf/yum, or pacman).
- Enables and starts the daemon, adds the current user to the `docker` group.
- Skipped entirely on macOS — install Docker Desktop / OrbStack / Colima yourself.

#### VPS hardening (`config/linux_hardening.sh`)
Sensible defaults for a fresh cloud machine:
- **Timezone**: set to UTC (idempotent) + enable NTP
- **Swap**: creates `/swapfile` (2G) when RAM < 2 GB and no swap exists; skipped in containers
- **Unattended security upgrades**: `unattended-upgrades` (Debian/Ubuntu) or `dnf-automatic` (Fedora)
- **Firewall**: `ufw default deny incoming → allow OpenSSH → enable` (SSH allowed *before* enable, so you don't lock yourself out)
- **`fail2ban`**: enabled with default SSH jail
- **sshd hardening** (opt-in via `--harden-sshd`): disables root login + password authentication. Refuses to run unless `~/.ssh/authorized_keys` is populated.

## Project Structure

```
startup/
├── macos_installer.sh         # macOS entry point (bootstraps Homebrew, runs Brewfile)
├── linux_installer.sh         # Linux entry point
├── Brewfile                   # Declarative package list for macOS
├── config/
│   ├── variables.sh           # Shared flags, package manager detection, deploy_dotfile helper
│   ├── brew.sh                # Homebrew bootstrap + brew bundle install
│   ├── vim.sh
│   ├── tmux.sh
│   ├── zsh.sh
│   ├── docker.sh
│   ├── ssh.sh                 # ed25519 key generation + permission fixes
│   ├── macos_defaults.sh      # `defaults write` for Finder/Dock/keyboard
│   └── linux_hardening.sh     # timezone/swap/ufw/fail2ban/unattended-upgrades/sshd
├── dotfiles/
│   ├── .vimrc
│   ├── .tmux.conf
│   └── .zshrc
└── test/
    └── test_reentrant.sh
```

## Re-entrancy

The installer is safe to run multiple times. Each config module uses a marker string (or marker file for macOS defaults) to detect whether it's already managed:

| Tool             | Marker                                          |
|------------------|-------------------------------------------------|
| Vim              | `call plug#begin` in `~/.vimrc`                 |
| Tmux             | `tmux-plugins/tpm` in `~/.tmux.conf`            |
| Zsh              | `oh-my-zsh` in `~/.zshrc`                       |
| Brewfile         | `brew bundle` is itself idempotent              |
| macOS defaults   | `~/.cache/startup-macos-defaults-applied`       |
| SSH key          | presence of `~/.ssh/id_ed25519`                 |
| ufw / fail2ban   | systemd unit state + presence of binary         |

**On each run:**
- Already-installed packages are skipped
- Managed dotfiles are preserved; unmanaged ones are backed up to `~/.dotfiles_backup_<timestamp>/` before overwrite
- Plugins are only installed/updated when the config is new or changed (or with `--update` / `--force`)
- Failures are non-fatal — the script logs a warning and continues

**Status messages:**
- `[SUCCESS]` (green), `[INFO]` (blue), `[WARNING]` (yellow), `[ERROR]` (red), `[DRY-RUN]` (yellow)

## Customization

- **Brewfile**: edit to taste; `brew bundle install` honors taps, formulae, casks, mas apps
- **`~/.zshrc.local`**: sourced at the end of `.zshrc` for per-machine config that shouldn't go in the repo
- **Reapply macOS defaults**: `rm ~/.cache/startup-macos-defaults-applied && bash macos_installer.sh --force`

## Adding New Tools

1. Create `config/newtool.sh` with `install_newtool`, `configure_newtool`, and `setup_newtool` functions
2. Source and call it from `linux_installer.sh` and/or `macos_installer.sh`
3. Add the dotfile to `dotfiles/` and reference it via `deploy_dotfile ".newtoolrc"` in `configure_newtool`
4. Add a marker-string re-entrancy check in `configure_newtool`
5. (macOS-only tool) add the package to `Brewfile` instead of an ad-hoc `brew install`

## Post-Installation

1. Restart your terminal or run `source ~/.zshrc`
2. **Vim**: `:PlugInstall` if plugins didn't auto-install
3. **Tmux**: `Ctrl+a I` to install plugins
4. **Zsh**: `p10k configure` to set the prompt style (pick MesloLGS Nerd Font)
5. **Docker (macOS)**: install yourself — Docker Desktop, OrbStack, or Colima
6. **Docker (Linux)**: `newgrp docker` (or log out/in) to use docker without sudo
7. **macOS defaults**: log out/in for key repeat changes to fully apply
8. **SSH key**: copy the printed public key to GitHub, cloud provider, or remote `authorized_keys`

## Requirements

- **macOS**: Apple Silicon (arm64) only. Fresh install is fine — Homebrew is bootstrapped automatically.
- **Linux**: Ubuntu, Debian, Fedora, CentOS, Arch. `sudo` access. `curl` and `git` install themselves if missing.
- **Network**: required for downloading plugins, packages, dotfiles

## Troubleshooting

- **Shell didn't change**: `chsh -s $(which zsh)`
- **Vim plugins missing**: open vim and run `:PlugInstall`
- **Tmux plugins missing**: in tmux, press `Ctrl+a I`
- **Docker permission denied (Linux)**: run `newgrp docker` or log out and back in
- **macOS key repeat still slow**: log out and back in (system caches the values)
- **`ufw` locked me out**: log in via the cloud provider's console and `sudo ufw disable`
- **`tmux-256color` missing**: install the terminfo entry (`tic`) or fall back to `screen-256color` in `~/.tmux.conf`

## License

MIT
