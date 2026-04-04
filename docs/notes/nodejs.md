# 安装和升级 Node.js / npm
## 版本选择（2026-04）

- Node 18 已结束生命周期，不再建议继续作为默认开发版本。
- 如果某些工具（如 VS Code 中依赖 Node 的 MCP / Chrome DevTools 相关扩展）要求 `node >= 22.19`，优先使用 Node 24 LTS。
- Node 22 可以满足 `>= 22.19` 的最低要求，但当前更稳妥的默认选择是 Node 24 LTS。

## Ubuntu 安装 / 升级

### 方案对比

| 方案 | 是否需要 sudo | 是否会更新 `/usr/bin/node` | 适用场景 |
| --- | --- | --- | --- |
| NodeSource APT | 是 | 是 | 需要系统级 `node`，希望所有 shell / 服务都统一 |
| nvm | 否 | 否 | 用户级安装、便于切换版本 |
| nvm + `~/.local/bin` 稳定入口 | 否 | 否 | 无 sudo，但又希望 VS Code / 普通 PATH 默认拿到新版 node |

### 方案一：通过 NodeSource 安装 Node 24 LTS（有 sudo 时推荐）

::: tip nodesource/distributions
- https://github.com/nodesource/distributions
:::

```sh
curl -fsSL https://deb.nodesource.com/setup_24.x -o ~/nodesource_setup.sh
sudo bash ~/nodesource_setup.sh
sudo apt-get install -y nodejs
node -v
npm -v
```

说明：

- 这种方式会更新系统里的 `/usr/bin/node`。
- 如果机器上原来通过 Ubuntu 仓库安装的是 `nodejs 12.x`，NodeSource 会把它替换成新的 24.x。

### 方案二：通过 nvm 安装 Node 24（当前机器实际采用）

当前机器没有免密 `sudo`，无法无交互地直接更新系统 `/usr/bin/node`，因此实际采用了：

1. 用 `nvm` 安装新的 Node 24 LTS。
2. 把默认版本切到 24。
3. 在 `~/.local/bin` 创建稳定入口，让 VS Code / 普通 PATH 默认命中新版本。

#### 安装 nvm

```sh
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

安装后会在 shell 配置中加入：

```sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

重启终端，或手动执行：

```sh
source ~/.zshrc
# 或
source ~/.bashrc
```

#### 升级到 Node 24.14.1 并设为默认版本

```sh
nvm install 24.14.1
nvm alias default 24.14.1
nvm use default

node -v
npm -v
```

输出应类似：

```sh
v24.14.1
11.11.0
```

#### 为 VS Code / 普通 PATH 发布稳定入口

有些进程不会主动执行 `nvm use`，例如某些 GUI 程序、VS Code 扩展或非交互式命令。为了让它们也默认拿到新版 Node，可以把新版二进制链接到 `~/.local/bin`。

```sh
mkdir -p ~/.local/bin

ln -sfn "$HOME/.nvm/versions/node/v24.14.1/bin/node" ~/.local/bin/node
ln -sfn "$HOME/.nvm/versions/node/v24.14.1/bin/node" ~/.local/bin/nodejs
ln -sfn "$HOME/.nvm/versions/node/v24.14.1/bin/npm" ~/.local/bin/npm
ln -sfn "$HOME/.nvm/versions/node/v24.14.1/bin/npx" ~/.local/bin/npx
ln -sfn "$HOME/.nvm/versions/node/v24.14.1/bin/corepack" ~/.local/bin/corepack
```

验证：

```sh
command -v node
node -v
npm -v
corepack --version
```

如果 `~/.local/bin` 在 `PATH` 中排在较前面，那么不依赖 `nvm use` 的场景也会默认拿到新版 `node`。

## 本次升级的实际验证记录

### 当前环境基线

升级前：

```sh
node -v   # v18.16.0
npm -v    # 9.5.1
```

系统包中的旧版本仍然存在：

```sh
apt-cache policy nodejs
# Installed: 12.22.9...
```

升级后：

```sh
node -v   # v24.14.1
npm -v    # 11.11.0
```

### 回归验证

对当前机器上多个依赖 Node.js 的项目执行了安装与回归验证。常用命令包括：

```sh
npm ci --no-audit --no-fund
npm run lint
npm run typecheck
npm run test
npm run build
```

说明：

- 具体执行哪些脚本，取决于各项目实际提供的 `package.json scripts`。
- 并不是每个项目都会同时包含 `lint`、`typecheck`、`test`、`build`。

结果：当前机器上几个依赖 Node.js 的项目在升级后均通过安装与构建验证。

## 本次遇到的问题和解决办法

### 问题一：没有免密 sudo，无法无交互更新系统 `/usr/bin/node`

现象：

```sh
sudo -n true
# sudo: a password is required
```

解决：

- 不直接改系统包。
- 改用 `nvm install 24.14.1`。
- 再通过 `~/.local/bin` 发布稳定入口，让默认 `PATH` 指向新版 Node。

### 问题二：个别项目在 npm 11 下提示 `EBADENGINE`

原因：项目自己的 `engines.node` 元数据过期，不包含 22 / 24。

解决：更新项目根 `engines.node`，并同步锁文件。例如：

```json
"node": "^24 || ^22 || ^20 || ^18 || ^16"
```

如果项目原来声明得过窄，例如只允许 16 / 18 / 20，那么在 Node 24 + npm 11 下很容易出现这类兼容性告警。

### 问题三：npm 11 对 pnpm 专用 `.npmrc` 配置给出告警

现象：

```sh
npm warn Unknown project config "shamefully-hoist"
npm warn Unknown project config "strict-peer-dependencies"
npm warn Unknown project config "resolution-mode"
```

原因：这些是 pnpm 配置，放在 `.npmrc` 里时，npm 11 会提示未知配置。

影响：

- 不影响 `npm ci`
- 不影响 `lint`
- 不影响类型检查命令
- 不影响 `test`
- 不影响 `build`

处理建议：

- 如果项目以后固定只用 npm，可以清理这些 pnpm 专用配置。
- 如果项目仍会混用 pnpm，这些告警可以暂时接受。

## Windows 安装

- 官方下载页：https://nodejs.org/en/download
- 当前 LTS 示例：https://nodejs.org/dist/v24.14.1/node-v24.14.1-x64.msi

安装后验证：

```sh
node -v
npm -v
```

## npm 换国内源

查看默认源：

```sh
npm config get registry
```

更换为淘宝镜像：

```sh
npm config set registry https://registry.npmmirror.com
```

Ubuntu 下配置文件通常在：`~/.npmrc`

Windows 下配置文件通常在：`C:\Users\<username>\.npmrc`

内容示例：

```sh
registry=https://registry.npmmirror.com
```