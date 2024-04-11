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

## .zshrc

::: tip See: <a href="./configs/.zshrc" target="_blank">./configs/.zshrc</a>
:::