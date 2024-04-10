# 安装 hstr

## 安装

```sh
sudo add-apt-repository ppa:ultradvorka/ppa
sudo apt-get update
sudo apt-get install hstr
```

## 配置
```sh
hstr --show-bash-configuration >> ~/.bashrc
```

或者在 `~/.bashrc` 中添加：

```sh
# HSTR configuration - add this to ~/.bashrc
alias hh=hstr                    # hh to be alias for hstr
export HSTR_CONFIG=hicolor       # get more colors
shopt -s histappend              # append new history items to .bash_history
export HISTCONTROL=ignorespace   # leading space hides commands from history
export HISTFILESIZE=10000        # increase history file size (default is 500)
export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)
# ensure synchronization between bash memory and history file
export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
if [[ $- =~ .*i.* ]]; then bind '"\C-r": "\C-a hstr -- \C-j"'; fi
# if this is interactive shell, then bind 'kill last command' to Ctrl-x k
if [[ $- =~ .*i.* ]]; then bind '"\C-xk": "\C-a hstr -k \C-j"'; fi
export HSTR_TIOCSTI=y
```

```sh
bash
```

输入 `hh` 打开历史命令。

::: tip See: dvorka/hstr: bash and zsh shell history suggest box - easily view, navigate, search and manage your command history.
* https://github.com/dvorka/hstr/tree/master
* https://github.com/dvorka/hstr/blob/master/INSTALLATION.md#ubuntu
* https://github.com/dvorka/hstr/tree/master?tab=readme-ov-file#configuration
:::