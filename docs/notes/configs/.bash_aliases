# aliases
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
alias tn="tmux new -s"
alias tl="tmux ls"
alias ts="tmux select-pane -T"

alias k9="kill -9"
alias lt="ls -lt"