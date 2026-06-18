# Enable Powerlevel10k instant prompt (must be at top of .zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Zsh configuration with Oh My Zsh and plugins

# ========================
# Oh My Zsh Configuration
# ========================

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme - using powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Update settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 13

# ========================
# Plugins
# ========================

plugins=(
    # Core plugins
    git
    history
    sudo
    colored-man-pages
    
    # Completion plugins
    zsh-completions
    
    # Syntax and suggestions
    zsh-autosuggestions
    zsh-syntax-highlighting
    
    # Utilities
    extract
    copybuffer
    copypath
    copyfile
)

# ========================
# Load Oh My Zsh
# ========================

source $ZSH/oh-my-zsh.sh

# ========================
# User Configuration
# ========================

# Preferred editor
export EDITOR='vim'
export VISUAL='vim'

# Language environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ========================
# History Settings
# ========================

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# History options
setopt SHARE_HISTORY           # Share history between sessions
setopt HIST_IGNORE_DUPS        # Don't record duplicate entries
setopt HIST_IGNORE_SPACE       # Don't record entries starting with space
setopt HIST_VERIFY             # Show command before executing from history
setopt HIST_EXPIRE_DUPS_FIRST  # Expire duplicates first
setopt HIST_FIND_NO_DUPS       # Don't show duplicates in search
setopt HIST_REDUCE_BLANKS      # Remove blank lines from history

# ========================
# Directory Navigation
# ========================

setopt AUTO_CD                 # cd by typing directory name
setopt AUTO_PUSHD              # Push old directory onto stack
setopt PUSHD_IGNORE_DUPS       # Don't push duplicates
setopt PUSHD_MINUS             # Use - for popd

# ========================
# Aliases
# ========================

# File operations
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safe operations
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Grep with color
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Modern alternatives (if available)
command -v exa &> /dev/null && alias ls='exa --icons'
command -v bat &> /dev/null && alias cat='bat'
command -v fd &> /dev/null && alias find='fd'
command -v rg &> /dev/null && alias grep='rg'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Configuration file shortcuts
alias zshconfig="vim ~/.zshrc"
alias zshreload="source ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias vimconfig="vim ~/.vimrc"
alias tmuxconfig="vim ~/.tmux.conf"

# Tmux
alias tmux='tmux -2'
alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'
alias tk='tmux kill-session -t'

# System
# macOS netstat uses different flags than Linux; use lsof as a cross-platform alternative
if [[ "$(uname -s)" == "Darwin" ]]; then
    alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
else
    alias ports='netstat -tulanp'
fi
alias myip='curl ifconfig.me'

# ========================
# Functions
# ========================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract archives
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick find file
ff() {
    find . -type f -name "*$1*"
}

# Quick find directory
# Named fdir to avoid shadowing the 'fd' binary (brew install fd)
fdir() {
    find . -type d -name "*$1*"
}

# Create backup of file
backup() {
    cp "$1" "$1.backup-$(date +%Y%m%d-%H%M%S)"
}

# ========================
# PATH Configuration
# ========================

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Add custom scripts directory if it exists
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"

# ========================
# Plugin Configuration
# ========================

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# zsh-syntax-highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)

# ========================
# Powerlevel10k
# ========================

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ========================
# Additional Configuration
# ========================

# Load custom configuration if it exists
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
