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

本仓库的 `vscodex` 命令适用于 Windows 本机的 VS Code 稳定版和 `openai.chatgpt` 扩展。同一 Windows 用户的所有账号共用原来的 Codex 目录，包括活动会话、归档、索引和同一份 `config.toml`。普通终端中的 `codex` 继续使用原来的登录身份。启动器通过扩展的开发选项 `chatgpt.cliExecutable` 启动自带的后端，在窗口启动时通过 app-server 协议载入所选账号。[Codex 登录说明](https://developers.openai.com/codex/auth) · [扩展设置](https://developers.openai.com/codex/ide/settings)

在仓库根目录用 PowerShell 安装。需要 Python 3.9+ 和 Windows 自带的 .NET Framework 4.x 编译器。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\notes\scripts\vscode-codex-account\install.ps1
```

首次登录新账号时，在 PowerShell 或 cmd 中输入完整邮箱，再按终端提示完成设备码授权。工具会核对浏览器实际授权的邮箱并保存凭证。

如果 VS Code 用户设置中配置了 `http.proxy`，设备码登录会使用该代理，与扩展后端一致。未配置时，登录进程沿用当前终端的代理环境变量。

```powershell
vscodex login team.alpha@example.com
vscodex login team.beta@example.com
```

对于已有账号，`login` 和 `use` 都接受完整邮箱或唯一的连续片段，匹配时忽略大小写。完整邮箱只匹配该地址。上例中的 `alpha` 只匹配第一个邮箱。输入 `team` 会列出两个候选邮箱，保留当前选择。升级前已登记的账号可以直接按邮箱使用，已有凭证会继续沿用。

选择后，在需要切换的 VS Code 窗口按 `Ctrl+Shift+P`，执行 **Developer: Reload Window**。其他已打开的窗口继续使用启动时的账号。重载后可在 Codex 账号菜单查看邮箱和额度。

```powershell
vscodex use beta
vscodex status
vscodex use team.alpha@example.com
```

`status` 顶部显示下次重载时选用的账号。账号列表中，蓝色表示邮箱，天蓝色 `[cached]` 表示已有登录凭证，红色提示待授权或凭证异常。绿色 `[in use]` 表示当前至少有一个 VS Code 窗口的 Codex 后端正在使用该账号。升级前已打开的窗口重载一次即可显示此标记。

`login` 和 `use` 用绿色提示成功、红色提示失败。`use` 还会用蓝色显示目标账号，用天蓝色突出窗口重载命令。首次授权成功后，扩展可直接刷新该账号的令牌。如果服务端撤销了授权，可运行 `vscodex login beta --again`。设备码登录如被禁用，请在 ChatGPT 的安全设置中启用，或联系工作区管理员。[设备码授权说明](https://developers.openai.com/codex/auth)

各账号的 `auth.json` 位于 `%LOCALAPPDATA%\vscode-codex-account\accounts` 下各自的子目录。原来的 Codex 目录默认为 `%USERPROFILE%\.codex`。如果安装前使用了自定义 `CODEX_HOME`，安装器会记录该目录。修改其中的 `config.toml` 后，所有账号在下次加载配置时都会读到修改。`vscodex use original` 可让窗口恢复使用原目录的登录身份。

从旧版升级时，重新运行上面的安装命令，再重载各个 VS Code 窗口。安装器会将旧账号目录中的会话、归档、标题索引和分页历史合入共享目录，并保留旧文件。新窗口会在后台检查尚未导入的历史，打开 Codex 时可以直接加载账号。

如果同一条会话在两个目录中已有不同内容，窗口使用共享目录中的版本，旧版本保留在原账号目录，其余会话继续导入。如果曾在某个账号目录单独调整过 `config.toml`，可从保留的副本中挑选需要的设置合入共享配置。

#### 在另一个窗口继续同一条会话

若新窗口提示 **This is open in another app**，可以让持锁窗口单独释放这条会话。等目标会话的当前回合结束后，在任意终端运行以下命令，把示例标题替换成侧栏中显示的完整名称。

```powershell
vscodex release "项目开发"
```

命令只向持锁窗口请求释放这条空闲会话，原窗口及其他会话可以继续工作。Codex 默认可能需要约一分钟交还写锁。看到释放成功后，在目标窗口点击 **Retry**。两个窗口都保留这条会话的历史；交接期间请避免在原窗口再次打开它。

标题重复时，命令会列出匹配的会话 UUID，可用 `vscodex release 完整UUID` 精确选择。正在运行或等待批准的会话会提示稍后重试。**安装新版前已经启动的持锁窗口**需要在其现有任务结束后重载一次，才能接收这个命令。之后逐条释放会话不需要再重载窗口。

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
