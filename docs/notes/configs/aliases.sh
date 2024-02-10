# --show-control-chars: help showing Korean or accented characters
alias ls='ls -F --color=auto --show-control-chars'
alias ll='ls -l'

# Add aliases here

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