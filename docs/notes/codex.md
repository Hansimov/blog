# 安装 Codex

## 安装 CLI

### Windows / Linux

Windows 在 `cmder` 或者 `git bash` 中执行以下命令：

```bash
npm i -g @openai/codex@latest
```

### VSCode 安装插件

直接搜索安装即可。

## 登录

::: tip Token exchange failed: token endpoint returned status 403 Forbidden · Issue #2414 · openai/codex
https://github.com/openai/codex/issues/2414
:::

### Windows

直接在 cmder 命令行运行：

```bash
codex
```

登录好后，登录信息会保存在：`C:\Users\<Username>\.codex\auth.json`

Linux 的在：`~/.codex/auth.json`

### VSCode 插件登录

在 CLI 登录后，默认就是登录状态了。

### Linux 登录

可以考虑在 VSCode 插件中登录。或者复制 `auth.json` 到 Linux 的 `~/.codex/auth.json` 中。

如果在 VSCode 中在远程服务器的插件中登录了，那么默认就是登录状态了。

## MCP 服务

### Playwright

需要 npx 安装 Playwright ：

```sh
npx -y playwright@latest install chromium
```

需要在 `config.toml` 中添加：

```sh
[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest"]
startup_timeout_sec = 60
tool_timeout_sec = 300
```

###  Playwright 启动问题

::: warning 下面的方法实测似乎无效。重新运行上面的安装 playwright 的命令，然后重启 Codex 的 VSCode 插件 或者 CLI ，问题就解决。
:::

如果遇到启动问题，可以在后台启动 Playwright MCP 服务：

```sh
npx -y @playwright/mcp@latest --port 28931
```

然后配置修改为：

```sh
[mcp_servers.playwright]
url = "http://localhost:28931/mcp"
startup_timeout_sec = 30
tool_timeout_sec = 300
```

### Codex Apps

启动时会报错。实际上也用不着，因此可以禁用。

在 `config.toml` 中添加：

```sh
[features]
apps = false
```

## 配置和环境样例

- Windows: `C:\Users\<Username>\.codex`
- Linux: `~/.codex`


<details open> <summary><code>config.toml</code></summary>

<<< @/notes/configs/.codex/config.toml

</details>

<details open> <summary><code>.env</code></summary>

<<< @/notes/configs/.codex/.env

</details>
