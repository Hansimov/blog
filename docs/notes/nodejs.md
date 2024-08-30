# 安装 node.js 和 npm


## Ubuntu 安装

### (推荐) 通过 nodesource 安装 node.js 和 npm

::: tip nodesource/distributions: NodeSource Node.js Binary Distributions
* https://github.com/nodesource/distributions
:::

```sh
curl -fsSL https://deb.nodesource.com/setup_18.x -o ~/nodesource_setup.sh
bash ~/nodesource_setup.sh
sudo apt-get install -y nodejs
node -v && npm -v
```

### (不推荐) 通过 nvm 安装 node.js

#### 安装 nvm

```sh
wget -qO- https://raw.staticdn.net/nvm-sh/nvm/v0.39.7/install.sh | bash
```

输出形如：

```sh
=> nvm source string already in /home/asimov/.zshrc
=> bash_completion source string already in /home/asimov/.zshrc
```

会自动在 `.zshrc` 里添加：

```sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
```

nvm 默认安装在 `$HOME/.nvm`。需要重启终端（`bash` 或 `zsh`）以使 `nvm` 生效。

查看版本：

```sh
# source ~/.zshrc
# source ~/.bashrc
nvm -v
```

#### 通过 nvm 升级 node.js 到 18.16.0

一些框架（如 VitePress）要求 node.js 的版本为 18.x 或更高，而 Ubuntu 22.04 通过 apt 安装的 node.js 版本默认为 12.x。

这里使用代理以提高下载速度：

```sh
https_proxy=http://127.0.0.1:11111 nvm install 18.16.0
nvm use 18.16.0
# node -v
```

#### 安装 npm

```sh
sudo apt update
sudo apt install npm
# npm -v
```

## Windows 安装

- https://nodejs.org/en/download/prebuilt-binaries
- https://nodejs.org/dist/v18.20.4/node-v18.20.4-x64.msi

查看版本：

```sh
node -v
npm -v
```

## npm 换国内源

查看默认源：

```sh
npm config get registry
```

更换为淘宝源：

```sh
npm config set registry https://registry.npmmirror.com
```

Ubuntu 下的配置文件在 `~/.npmrc`：

Windows 下的配置文件在 `C:\Users\<username>\.npmrc`：

其内容应为：

```sh
registry=https://registry.npmmirror.com
```