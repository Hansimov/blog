# 安装 zsh

## 安装

```sh
apt install zsh
```

::: tip See: Installing ZSH
- https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
- https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#ubuntu-debian--derivatives-windows-10-wsl--native-linux-kernel-with-windows-10-build-1903
:::


## 添加别名

将下列内容添加到 `~/.zshrc` 中：

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.bash_aliases
:::
<<< @/notes/configs/.bash_aliases

## 自动补全

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
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#00ffff"
source ~/.zsh/zsh-autosuggestions.zsh
```

::: tip See: zsh-autosuggestions
- https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#manual-git-clone
:::