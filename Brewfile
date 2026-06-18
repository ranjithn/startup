# Brewfile — declarative package list for macOS.
# Apply with: brew bundle install --file=Brewfile
# Edit to taste; the macos_installer.sh runs this automatically.

# Core CLI tooling (also installed by the individual config/*.sh modules,
# but listing here lets `brew bundle` do it in one shot)
brew "git"
brew "curl"
brew "vim"
brew "tmux"
brew "zsh"

# Nerd Font for Powerlevel10k icons (selected during `p10k configure`)
cask "font-meslo-lg-nerd-font"

# Docker Desktop — provides the daemon on macOS.
# If your org's license terms preclude Docker Desktop, comment this out
# and use `brew install colima docker docker-compose` instead.
cask "docker"
