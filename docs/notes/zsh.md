# 安装 zsh

## 安装

```sh
apt install zsh
```

::: tip See: Installing ZSH
- https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
- https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#ubuntu-debian--derivatives-windows-10-wsl--native-linux-kernel-with-windows-10-build-1903
:::

## 修改 PROMPT

在 `~/.zshrc` 中，注释原有 prompt 样式，添加下列内容：

```sh
# prompt adam1
PROMPT='%F{yellow}%~ # %f'
```

## 添加别名

将下列内容添加到 `~/.zshrc` 中：

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.bash_aliases
:::
<<< @/notes/configs/.bash_aliases

## 绑定按键
用下面的命令显示按键对应的字符：

```sh
showkey -a
```

`ctrl` + `D` 退出该界面。

将下列内容添加到 `~/.zshrc` 中：

```sh
# bind keys
bindkey "^[[1;5C" forward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1~"   beginning-of-line
bindkey "^[[4~"   end-of-line
bindkey "^[[3~"   delete-char
bindkey "^[^[[3~" delete-word
```

重启 `zsh` 或者 `source ~/.zshrc` 使配置生效。

::: tip See: zsh - Ctrl + left/right arrow keys issue - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/58870/ctrl-left-right-arrow-keys-issue

ubuntu - Fix key settings (Home/End/Insert/Delete) in .zshrc when running Zsh in Terminator Terminal Emulator - Stack Overflow
* https://stackoverflow.com/questions/8638012/fix-key-settings-home-end-insert-delete-in-zshrc-when-running-zsh-in-terminat

line editor - zsh kill Ctrl + Backspace, Ctrl + Delete - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/12787/zsh-kill-ctrl-backspace-ctrl-delete
:::

## 自动建议

```sh
cd ~
mkdir .zsh && cd .zsh
touch zsh-autosuggestions.zsh
```

复制下列脚本内容到 `~/.zsh/zsh-autosuggestions.zsh` 中：

- https://raw.githubusercontent.com/zsh-users/zsh-autosuggestions/master/zsh-autosuggestions.zsh


将下列内容添加到 `~/.zshrc` 中：

```sh
# auto suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"
source ~/.zsh/zsh-autosuggestions.zsh
```

::: tip See: zsh-autosuggestions
- https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#manual-git-clone
:::


## 自动补全

```sh
cd .zsh
git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git
```

将下列内容添加到 `~/.zshrc` 中：

```sh
# auto complete
source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
# style of auto complete
zstyle ':completion:*'  list-colors '=*=96'
```

并注释掉所有 `compinit` 相关的语句：

```sh
# # Use modern completion system
# autoload -Uz compinit
# compinit
```

然后创建 `~/.zshenv` 文件：

```sh
cd ~
touch .zshenv
```

将下列内容添加到 `~/.zshenv` 中：

```sh
skip_global_compinit=1
```

::: tip See: marlonrichert/zsh-autocomplete
* https://github.com/marlonrichert/zsh-autocomplete

See: 快捷键：
* https://github.com/marlonrichert/zsh-autocomplete?tab=readme-ov-file#keyboard-shortcuts
:::

::: tip See: How to change zsh-autocomplete color or make text item list under like zsh-autosuggestions
- https://github.com/ohmyzsh/ohmyzsh/issues/9728

See: ANSI escape code:
- https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
:::


## 设置 zsh 为默认 shell

```sh
chsh -s $(which zsh)
```

在 `.tmux.conf` 中添加：

```sh
# which zsh
set-option -g default-shell /usr/bin/zsh
```

::: tip See: command line - How to make ZSH the default shell? - Ask Ubuntu
- https://askubuntu.com/questions/131823/how-to-make-zsh-the-default-shell
:::

## 一键配置

```sh
wget https://raw.githubusercontent.com/Hansimov/blog/main/docs/notes/scripts/zsh_setup.sh -O ~/zsh_setup.sh && chmod +x ~/zsh_setup.sh && ~/zsh_setup.sh
```

## .zshrc 完整样例

::: info See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.zshrc
:::

<<< @/notes/configs/.zshrc{sh}

