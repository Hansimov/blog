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
# zstyle ':autocomplete:*' append-semicolon no
# bindkey -M emacs \
#     "^[OA"  .up-line-or-history \
#     "^[OB"  .down-line-or-history

# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/home/asimov/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/home/asimov/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/home/asimov/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/home/asimov/miniconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# # <<< conda initialize <<<

# alias cda="conda activate ai"
# alias cdd="conda deactivate"
# alias nu="gpustat -cpu -i -F -P"
# # alias cu='cat /sys/class/thermal/thermal_zone*/temp | awk '\''{ print ($1 / 1000) "°C" }'\'''
# alias cu='sensors | grep Tctl | head -1'
# alias ct="gh copilot"
# alias ce="gh copilot explain"
# alias cs="gh copilot suggest -t shell"

# conda activate ai

# Envs
export HF_ENDPOINT=https://hf-mirror.com
# export PATH=/usr/lib/postgresql/16/bin:$PATH
# export PG_CONFIG=/Library/PostgreSQL/16/bin/pg_config
# export ES_HOME=~/elasticsearch-8.17.3
# export ELASTIC_PASSWORD="***************-****" # CHANGE_TO_YOUR_OWN
# export PATH=$ES_HOME/bin:$PATH
# export KIBANA_HOME=~/kibana-8.17.3
# export PATH=$KIBANA_HOME/bin:$PATH
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# export GOROOT=/usr/local/go
# export GOPATH=$HOME/go
# export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
# export GOPROXY="https://mirrors.aliyun.com/goproxy,direct"

# export SUDOPASS=****  # CHANGE_TO_YOUR_OWN
# export PATH=$HOME/gradle-8.14.1/bin:$PATH
# export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
# export PATH=$JAVA_HOME/bin:$PATH

# # set up Xvfb for headless GUI applications
# Xvfb -ac :99 -screen 0 1280x1024x16 &
# export DISPLAY=:99 DBUS_SESSION_BUS_ADDRESS=none
# # reset display
# # xdpyinfo -display :10.0
# # export DISPLAY=localhost:10.0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"