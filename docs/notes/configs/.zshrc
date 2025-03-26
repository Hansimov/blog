# Set up the prompt

autoload -Uz promptinit
promptinit
# prompt adam1
PROMPT='%F{yellow}%~ # %f'

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Use modern completion system
# autoload -Uz compinit
# compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# aliases
alias ls="ls --color"

alias gs="git status"
alias gb="git rev-parse --abbrev-ref HEAD"
alias gba="git -P branch"
alias gd="git diff"
alias gdp="git -P diff"
alias gdh="git diff HEAD^ HEAD"
alias gl="git log"
alias gn="git --no-pager log --pretty='format:%Cgreen[%h] %Cblue[%ai] %Creset[%an]%C(Red)%d %n  %Creset%s %n' -n5"
alias ga="git add"
alias gc="git commit"
alias gk="git checkout"
alias gau="git add -u"
alias gcm="git commit -m"
alias gcan="git commit --amend --no-edit"
alias gp="git push"
alias gpf="git push -f"
alias gacp="git add -u && git commit --amend --no-edit && git push -f"

alias ta="tmux a"
alias td="tmux detach"
alias tn="tmux new -s x"
alias tl="tmux ls"
alias ts="tmux select-pane -T"

alias tm="top -o %MEM -d 2 -c"
alias tc="top -o %CPU -d 2 -c"

alias k9="kill -9"
alias lt="ls -lt"
alias hi="hostname -i"

alias cda="conda activate ai"
alias cdd="conda deactivate"

alias nu="gpustat -cpu -i"

# bind keys
bindkey "^[[1;5C" forward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1~"   beginning-of-line
bindkey "^[[4~"   end-of-line
bindkey "^[[3~"   delete-char
bindkey "^[^[[3~" delete-word

# auto suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"
source ~/.zsh/zsh-autosuggestions.zsh

# auto complete
source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
# style of auto complete
zstyle ':completion:*'  list-colors '=*=96'

# Environment variables

# huggingface mirror
export HF_ENDPOINT=https://hf-mirror.com
# postgres
# export PATH=/usr/lib/postgresql/16/bin:$PATH
# export PG_CONFIG=/Library/PostgreSQL/16/bin/pg_config
