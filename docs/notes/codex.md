# 安装 Codex

## 安装 CLI

### Windows / Linux

Windows 在 `cmder` 或者 `git bash` 中执行以下命令：

```bash
npm i -g @openai/codex@latest
```

### VSCode 安装插件

直接搜索 `@id:openai.chatgpt` 安装即可。

如果是用 Remote SSH 连接到远程 Linux 服务器，有时候安装时会出现问题，可以在远程服务器上写入并运行下面的脚本：

<details> <summary><code>install_vsc_codex.sh</code></summary>

<<< @/notes/scripts/install_vsc_codex.sh

</details>

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

#### Windows 本机切换两个 ChatGPT 账号

本仓库的 `vscodex` 命令适用于 Windows 本机的 VS Code 稳定版和 `openai.chatgpt` 扩展。它通过用户设置 `chatgpt.cliExecutable` 启动扩展自带的后端，为每个账号指定独立的 `CODEX_HOME`。普通终端中的 `codex` 仍使用原来的登录环境。该设置属于扩展的开发选项，扩展更新后可用下列命令重新验证。[Codex 登录说明](https://developers.openai.com/codex/auth) · [扩展设置](https://developers.openai.com/codex/ide/settings)

在仓库根目录用 PowerShell 安装。需要 Python 3.9+ 和 Windows 自带的 .NET Framework 4.x 编译器。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\notes\scripts\vscode-codex-account\install.ps1
```

首次使用时，在 PowerShell 或 cmd 中登记别名和实际邮箱，再按终端提示逐个完成设备码授权。工具会核对浏览器实际授权的邮箱。以下两个地址是示例。

```powershell
vscodex add primary first@example.com
vscodex add secondary second@example.com
vscodex login primary
vscodex login secondary
```

日常切换可以输入别名、完整邮箱或唯一前缀，大小写均可。以上面的两个邮箱为例，`fi` 选中第一个，`se` 选中第二个。命令会显示选中的完整邮箱。若前缀对应多个账号，会列出候选项并保留当前选择。

选择后，在需要切换的 VS Code 窗口按 `Ctrl+Shift+P`，执行 **Developer: Reload Window**。其他已打开的窗口继续使用启动时的账号。重载后可在 Codex 账号菜单查看邮箱和额度。

```powershell
vscodex use se
vscodex status
vscodex use first@example.com
```

`status` 显示本机缓存和下次窗口加载时的选择。首次授权成功后，扩展可直接刷新该账号的令牌。如果服务端撤销了授权，可运行 `vscodex login secondary --again`。设备码登录如被禁用，请在 ChatGPT 的安全设置中启用，或联系工作区管理员。[设备码授权说明](https://developers.openai.com/codex/auth)

账号资料保存在当前 Windows 用户的 `%LOCALAPPDATA%\vscode-codex-account\accounts`。每个账号第一次登录时会复制原 Codex 目录中的 `config.toml` 和 `AGENTS.md`（如果存在），然后独立保存凭证、会话和后端配置。原来的聊天记录可通过 `vscodex use original` 并重载窗口重新访问。换机器时重新安装并授权即可。

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
