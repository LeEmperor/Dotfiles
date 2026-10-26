# ~/.zshrc — 43PR zsh setup (github.com/43PR/dotfiles), adapted for Ubuntu,
# plus what used to live in ~/.bashrc.

# --------------------------------------------------
# PATH (bash got ~/.local/bin from ~/.profile; ~/.zprofile does that for login shells)
# --------------------------------------------------

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
typeset -U PATH path   # drop duplicates

# Remote machines often lack ghostty's terminfo
if [ "$TERM" = "xterm-ghostty" ]; then
    export TERM=xterm-256color
fi

# --------------------------------------------------
# Live autocompletion (must be sourced FIRST, before compinit)
# --------------------------------------------------

source ~/.local/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# Start suggesting after 1 character, with a tiny delay so it feels smooth
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:*' delay 0.05

# Tab cycles through the menu, Shift+Tab goes backwards
bindkey '^I' menu-complete
bindkey "$terminfo[kcbt]" reverse-menu-complete

# Keep Up/Down arrows as normal history navigation
bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history

# --------------------------------------------------
# Prompt
# --------------------------------------------------

eval "$(starship init zsh)"

# --------------------------------------------------
# eza (monochrome)
# --------------------------------------------------

export EZA_COLORS="uu=bright-black:gu=bright-black:da=bright-black:ur=white:uw=bright-black:ux=white:ue=bright-black:gr=bright-black:gw=bright-black:gx=white:tr=bright-black:fi=white:di=bright-white:ln=bright-black:pi=bright-black:so=bright-black:bd=bright-black:cd=bright-black:or=bright-black:mi=bright-black:ex=white"

alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons'

alias grep='grep --color=auto'

# --------------------------------------------------
# Completion styling
# --------------------------------------------------

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Grayscale completion colors
zstyle ':completion:*' list-colors \
  '=(#b)*(=0)=38;5;250' \
  '=(#b)*(=1)=38;5;255' \
  '=(#b)*(=2)=38;5;245' \
  '=(#b)*(=3)=38;5;240'

# Dim group headers
zstyle ':completion:*:descriptions' format '%F{8}-- %d --%f'

# --------------------------------------------------
# History
# --------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# --------------------------------------------------
# Personal aliases & functions (shared with bash)
# --------------------------------------------------

source ~/.bash_configs

# yazi: cd into the directory yazi was in when it quit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

alias czsh="vim ~/.zshrc"

# --------------------------------------------------
# Autosuggestions
# --------------------------------------------------

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# --------------------------------------------------
# Syntax highlighting (keep LAST)
# --------------------------------------------------

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

ZSH_HIGHLIGHT_STYLES[command]='fg=white'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=white'
ZSH_HIGHLIGHT_STYLES[function]='fg=white'
ZSH_HIGHLIGHT_STYLES[alias]='fg=white'
ZSH_HIGHLIGHT_STYLES[path]='fg=245'
ZSH_HIGHLIGHT_STYLES[comment]='fg=240'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=245'

# --------------------------------------------------
# 43PR theme controller
# --------------------------------------------------

theme() { python3 "$HOME/.config/43pr/bin/theme.py" "$@"; }
