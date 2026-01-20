# Startup Scripts

A collection of modular installer scripts to set up development environments on new machines. Currently supports Linux with plans to expand to macOS and additional tools.

## Features

- **Modular Design**: Easy to extend with new tools and platforms
- **Remote Execution**: Run directly from GitHub without cloning
- **Local Execution**: Can also be run from a local clone
- **Good Defaults**: Comes with sensible configurations and popular plugins
- **Multiple Package Managers**: Supports apt, dnf, yum, and pacman

## Quick Start

### Remote Installation (Recommended)

Run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/startup/main/linux_installer.sh | bash
```

Or with custom GitHub variables:

```bash
GITHUB_USER=yourusername GITHUB_REPO=startup GITHUB_BRANCH=main \
  curl -fsSL https://raw.githubusercontent.com/yourusername/startup/main/linux_installer.sh | bash
```

### Local Installation

Clone and run locally:

```bash
git clone https://github.com/yourusername/startup.git
cd startup
bash linux_installer.sh
```

## What Gets Installed

### Linux Installer

The Linux installer sets up the following tools with good defaults and plugins:

#### Vim
- **Plugin Manager**: vim-plug
- **Plugins**:
  - NERDTree (file explorer)
  - vim-airline (status line)
  - vim-fugitive (git integration)
  - fzf (fuzzy finder)
  - vim-gitgutter (git diff in sign column)
  - gruvbox theme
  - And more...
- **Features**: Line numbers, syntax highlighting, smart indentation, clipboard integration

#### Tmux
- **Plugin Manager**: TPM (Tmux Plugin Manager)
- **Plugins**:
  - tmux-resurrect (session persistence)
  - tmux-continuum (automatic session saving)
  - tmux-yank (copy to system clipboard)
  - tmux-pain-control (pane navigation)
- **Features**: 
  - Custom prefix (Ctrl+a)
  - Mouse support
  - Vi mode
  - Custom key bindings
  - Beautiful status bar

#### Zsh
- **Framework**: Oh My Zsh
- **Theme**: Powerlevel10k
- **Plugins**:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
  - zsh-completions
  - git, docker, kubectl, and more
- **Features**:
  - Smart history
  - Auto-completion
  - Useful aliases and functions
  - Directory shortcuts

## Project Structure

```
startup/
├── linux_installer.sh      # Main installer script for Linux
├── config/                  # Modular configuration files
│   ├── variables.sh         # Common variables and utility functions
│   ├── vim.sh               # Vim installation and configuration
│   ├── tmux.sh              # Tmux installation and configuration
│   └── zsh.sh               # Zsh installation and configuration
├── dotfiles/                # Configuration files
│   ├── .vimrc               # Vim configuration
│   ├── .tmux.conf           # Tmux configuration
│   └── .zshrc               # Zsh configuration
└── README.md                # This file
```

## Adding New Tools

To add a new tool (e.g., Python environment):

1. Create a new config file: `config/python.sh`
2. Define installation and configuration functions
3. Add the tool to the main installer script
4. (Optional) Add dotfiles if needed

Example structure for `config/python.sh`:

```bash
#!/bin/bash
# Python installation and configuration

install_python() {
    log_info "Installing Python..."
    # Installation logic
}

configure_python() {
    log_info "Configuring Python..."
    # Configuration logic
}

setup_python() {
    install_python
    configure_python
}
```

## Adding macOS Support

To add macOS support:

1. Create `macos_installer.sh` based on `linux_installer.sh`
2. Update package manager detection in config files
3. Use `brew` instead of apt/yum/dnf
4. Adjust any Linux-specific configurations

## Post-Installation

After running the installer:

1. **Restart your terminal** or run: `source ~/.zshrc`
2. **Vim**: Run `:PlugInstall` inside vim if plugins didn't install automatically
3. **Tmux**: Press `Ctrl+a` then `I` to install plugins
4. **Zsh**: Run `p10k configure` to customize your prompt
5. If your default shell didn't change: `chsh -s $(which zsh)`

## Customization

All configuration files are backed up to `~/.dotfiles_backup_<timestamp>` before being replaced. You can:

- Edit dotfiles directly in `~/` after installation
- Modify the dotfiles in this repo before running the installer
- Create local overrides in `~/.zshrc.local` (sourced by .zshrc)

## Requirements

- **OS**: Linux (Ubuntu, Debian, Fedora, CentOS, Arch Linux)
- **Privileges**: Sudo access for package installation
- **Network**: Internet connection to download plugins and themes
- **Tools**: curl and git (will be installed if missing)

## Troubleshooting

### Shell didn't change to Zsh
Run manually: `chsh -s $(which zsh)`

### Vim plugins not installed
Open vim and run: `:PlugInstall`

### Tmux plugins not installed
In tmux, press: `Ctrl+a` then `I` (capital i)

### Permission denied
Make the script executable: `chmod +x linux_installer.sh`

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for:

- Additional tool installers
- macOS support
- Bug fixes
- Documentation improvements

## License

MIT License - Feel free to use and modify as needed.

## Future Plans

- [ ] macOS installer
- [ ] Python environment setup
- [ ] Node.js/npm setup
- [ ] Docker setup
- [ ] AWS CLI setup
- [ ] Development tools (jq, htop, ripgrep, etc.)
- [ ] Programming language installers (Go, Rust, etc.)

