# Startup Scripts

Modular installer scripts for setting up development environments on new machines. Currently supports Linux.

## Features

- **Modular**: Easy to extend with new tools and platforms
- **Remote or local execution**: Run directly from GitHub or from a local clone
- **Re-entrant**: Safe to run multiple times — only installs/updates what's needed
- **Good defaults**: Sensible configurations and popular plugins out of the box
- **Multiple package managers**: apt, dnf, yum, pacman

## Quick Start

```bash
# Remote (recommended)
curl -fsSL https://raw.githubusercontent.com/ranjithn/startup/dev/linux_installer.sh | bash

# Local
git clone https://github.com/ranjithn/startup.git && cd startup
bash linux_installer.sh
```

## CLI Flags

```
--force    Reinstall everything, even if already present
--update   Update plugins only (git pull + PlugUpdate/TPM update); skips package installs and config deployment
--dry-run  Print what would be done without making any changes
```

Examples:
```bash
bash linux_installer.sh --dry-run          # preview changes
bash linux_installer.sh --update           # pull latest plugins
bash linux_installer.sh --force            # full reinstall
```

## What Gets Installed

### Vim
- **Plugin manager**: vim-plug
- **Plugins**: NERDTree, vim-airline, vim-fugitive, vim-gitgutter, gruvbox, and more
- **Config**: line numbers, syntax highlighting, smart indent, clipboard, mouse support

### Tmux
- **Plugin manager**: TPM
- **Plugins**: tmux-resurrect, tmux-continuum, tmux-yank, tmux-sensible
- **Config**: `Ctrl+a` prefix, mouse support, vi mode, custom status bar

### Zsh
- **Framework**: Oh My Zsh
- **Theme**: Powerlevel10k
- **Plugins**: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, git, docker, kubectl, and more

### Docker
- Installs Docker CE via the official repository (apt, dnf/yum, or pacman)
- Enables and starts the Docker service
- Adds the current user to the `docker` group so `docker` commands work **without sudo**

## Project Structure

```
startup/
├── linux_installer.sh      # Main entry point
├── config/
│   ├── variables.sh        # Shared variables, flags, and utility functions
│   ├── vim.sh
│   ├── tmux.sh
│   ├── zsh.sh
│   └── docker.sh
├── dotfiles/
│   ├── .vimrc
│   ├── .tmux.conf
│   └── .zshrc
└── test/
    └── test_reentrant.sh
```

## Re-entrancy

The installer is safe to run multiple times. Each config module uses a **marker string** to detect whether a file is already managed:

| Tool  | Marker                    |
|-------|---------------------------|
| Vim   | `call plug#begin`         |
| Tmux  | `tmux-plugins/tpm`        |
| Zsh   | `oh-my-zsh`               |

**On each run:**
- Already-installed packages are skipped
- Managed dotfiles are preserved; unmanaged ones are backed up before overwrite
- Plugins are only installed/updated when the config is new or changed (or with `--update`/`--force`)
- Failures are non-fatal — the script logs a warning and continues

**Status messages:**
- `[SUCCESS]` (green) — already installed or just succeeded
- `[INFO]` (blue) — action in progress
- `[WARNING]` (yellow) — non-fatal issue
- `[ERROR]` (red) — fatal problem
- `[DRY-RUN]` (yellow) — what would happen in dry-run mode

## Adding New Tools

1. Create `config/newtool.sh` with `install_newtool`, `configure_newtool`, and `setup_newtool` functions
2. Source and call it in `linux_installer.sh`
3. Add dotfiles to `dotfiles/` if needed

## Post-Installation

1. Restart your terminal or run `source ~/.zshrc`
2. **Vim**: `:PlugInstall` if plugins didn't auto-install
3. **Tmux**: `Ctrl+a` then `I` to install plugins
4. **Zsh**: `p10k configure` to customize your prompt
5. **Docker**: `newgrp docker` (or log out/in) to use docker without sudo

## Requirements

- **OS**: Linux (Ubuntu, Debian, Fedora, CentOS, Arch)
- **Privileges**: sudo access
- **Network**: internet connection for downloading plugins
- **Tools**: `curl` and `git` (installed automatically if missing)

## Troubleshooting

- **Shell didn't change**: `chsh -s $(which zsh)`
- **Vim plugins missing**: open vim and run `:PlugInstall`
- **Tmux plugins missing**: in tmux, press `Ctrl+a I`
- **Docker permission denied**: run `newgrp docker` or log out and back in

## License

MIT
