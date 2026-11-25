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

#### 远程窗口提示无法加载账号

Windows 本机窗口能用 Codex，Linux Remote-SSH 窗口却提示 **ChatGPT hit a snag / We couldn't load your account** 时，先在 SSH 窗口的**输出**面板查看 Codex 日志。远端 VS Code Server 默认也会将日志写入 `~/.vscode-server/data/logs/<日志会话>/exthost*/openai.chatgpt/Codex.log`。

如果第一条启动错误是 `Failed to spawn codex mcp process at C:\...`，说明远端扩展宿主尝试在 Linux 上启动 Windows 程序，后续的账号读取因此失败。`chatgpt.cliExecutable` 是应用级设置，SSH 窗口也会收到 Windows 用户设置中的值。即使已在远端设置里填写 Linux 可执行文件的绝对路径，也可能出现这个错误。

可以让两端通过同一个命令名 `vscodex-app-server` 启动各自的后端。在 Windows 终端运行以下命令即可用新窗口打开远程项目。`devbox` 填本机 SSH 配置中的主机别名，`/home/dev/repos/example/` 填远端项目的绝对路径。

```powershell
code --new-window --folder-uri "vscode-remote://ssh-remote+devbox/home/dev/repos/example/"
```

如果相同的远端文件夹已经打开，`--new-window` 可能会聚焦已有窗口，沿用原来启动的扩展宿主。修复后若点击 **Retry** 仍在日志中看到 `Codex process is not available`，请在该 SSH 窗口执行 **Developer: Reload Window**。要保留当前窗口并另开一份，可在该窗口的命令面板执行 **Workspaces: Duplicate As Workspace in New Window**。

在 SSH 窗口安装 Codex 扩展，然后在**远端 Linux** 的本仓库根目录，以运行 VS Code Server 的用户执行以下命令。远端需要 Bash 和 Python 3。

```bash
bash docs/notes/scripts/vscode-codex-account/install-linux.sh install
bash docs/notes/scripts/vscode-codex-account/install-linux.sh check
```

默认安装目录是 `~/.local/bin`。`check` 检查当前终端能否找到启动器，**VS Code Server 扩展宿主的 PATH** 也需要包含该目录。若扩展宿主使用其他用户 bin 目录，把该目录的绝对路径分别作为第二个参数传给 `install` 和 `check`。每台需要使用 Codex 的 Linux Remote-SSH 主机都要安装一次。

然后在 **Windows 本机**的本仓库根目录，用 PowerShell 启用 Remote-SSH 兼容模式。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\notes\scripts\vscode-codex-account\install.ps1 -RemoteSsh
```

在目标 SSH 窗口按 `Ctrl+Shift+P`，执行 **Developer: Reload Window**，打开 Codex 查看账号菜单。Windows 本机窗口继续使用 `vscodex use` 选定的账号。SSH 窗口运行远端扩展自带的 Linux 后端，使用远端的 `CODEX_HOME` 和已有凭证。SSH 窗口若使用回环代理，`127.0.0.1` 指的是远端主机，要确认该主机的相应端口有代理服务。

#### 会话显示 Ultra，滑块最高却只有 Extra High

Codex 的 `config.toml` 中，`model_reasoning_effort` 控制默认推理强度。滑块还会筛选当前模型支持的档位和 ChatGPT 账号允许显示的档位。因此，已有会话可以显示 Ultra，同一窗口的滑块却只到 Extra High。在选择器里选定其他档位时，扩展还可能将所选值写回配置文件。[Codex 配置参考](https://developers.openai.com/codex/config-reference/) · [ChatGPT 与 Codex 的模型可用性](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex)

在提供 **Settings → General → Available reasoning levels** 的客户端，用相同的 ChatGPT 账号勾选 **Max** 和 **Ultra**，保留原有勾选项。这是账号级显示偏好。Remote-SSH 若使用另一个账号，需要单独检查。随后在实际运行后端的主机上核对 `config.toml`；如果该模型支持 Ultra，且希望继续以它为默认值，确认 `model_reasoning_effort = "ultra"`。

在空白对话里打开当前模型的滑块验收，无需发送消息。若旧窗口仍显示先前的范围，等当前任务结束后，在该窗口执行 **Developer: Reload Window**。后端的 `model/list` 返回模型支持的档位，`config/read` 返回生效的默认值；滑块实际出现 Max 和 Ultra，才说明账号偏好也已生效。

#### 观察 Thinking 到首段文字的耗时

在运行 Codex 后端的机器上，从本仓库根目录执行监测脚本。把示例路径替换为该会话的工作区路径。Remote-SSH 会话使用远端路径，可通过 `python3` 执行同一脚本。

```powershell
python docs/notes/scripts/codex_turn_latency.py --workspace "D:\projects\example" --watch
```

同一目录有多条会话时，可用 `--thread UUID` 代替 `--workspace 路径`。脚本根据本地记录估算从用户消息到第一条助手文字的时间，并报告首次采样的输入缓存、后续已完成的采样数和已完成的上下文压缩。按 `Ctrl+C` 即可结束监测，模型回合继续运行。

#### 旧会话反复断流，新会话很快 {#old-thread-stream-retries}

在发生故障的机器上，用会话和回合的 UUID 查看连接时间线。省略 `--turn` 会选择传输日志中最近有记录的回合。日志保留期有限，复测时应记录原回合的 UUID。

```powershell
python docs/notes/scripts/codex_turn_latency.py --thread "会话UUID" --turn "回合UUID" --transport
```

2026-11-25，Windows 上两个 VS Code 项目的旧会话都完成了 WebSocket 升级（HTTP 101）。连接断开后，客户端重建连接、全量发送上下文，约 80 秒后再次断开。两个项目各有一组连续五次重试，这几分钟里没有记录到首个输出项。同机新开的会话使用同一代理，三个新连接从 101 到首个工具或推理输出项仅需 1.91–3.20 秒。

| 同晚的回合 | 当时本地历史项的 JSON 大小（近似） | 影响重发体积的内容 | HTTP 回退请求，zstd 压缩前 → 后 |
| --- | ---: | --- | ---: |
| 旧会话 A | 4.01 MB | 加密推理等字段共约 259 万字符，无内联图片 | 4,003,194 → 2,388,506 字节 |
| 旧会话 B | 2.22 MB | 6 个内联图片数据 URL，共约 158 万字符 | 2,121,654 → 1,371,513 字节 |
| 新会话 | 0.09 MB | 采样时无上述加密字段和内联图片 | 当时未观察到回退 |

这些字节数来自两个不同的观测点。历史项的大小根据当时的有效历史估算，最后一列取自客户端的 HTTP 压缩日志。WebSocket 的线上字节数以及服务端收到请求的时刻在该日志里均不可见。两个旧会话的 HTTP 压缩各花了 25 ms 和 7 ms。旧会话 B 当晚也曾在直连上得到 HTTP 200，较大的请求有时能成功，但等待可达数十秒。

#### Windows 和 Remote-SSH 上的 Codex 代理路径 {#windows-codex-upload}

这里把 `11111` 配置对应的远端 VMess 节点称为 **A（前置）**，把 `11119` 配置对应的远端节点称为 **B（原出口）**。`127.0.0.1:11111` 和 `127.0.0.1:11119` 都是 Codex 后端所在机器的 HTTP 代理监听地址。远端 VMess 服务有自己的地址、端口和认证。

| 场景 | Codex 首先连接 | 跨机器的路径 | Codex 服务看到的出口 |
| --- | --- | --- | --- |
| Windows 修复前 | Windows 的 `11119` | Windows → B → Codex 服务 | B 的出口 |
| Windows 修复后 | Windows 的 `11119` | Windows → A → B → Codex 服务 | B 的出口 |
| VS Code Remote-SSH 打开的 ai122 项目 | ai122 的 `11119` | ai122 → A → B → Codex 服务 | B 的出口 |
| Windows 应用直接选用 `11111` | Windows 的 `11111` | Windows → A → Codex 服务 | A 的出口 |

以访问 `chatgpt.com:443` 为例，修复后的 Windows 上发生了两次目标不同的 HTTP CONNECT。

1. Codex 向本机 `11119` 请求连接 **`chatgpt.com:443`**。`11119` 仍选择原来的 B 出站，使用 B 的 VMess 认证。
2. 为了抵达 B，这个出站的 `proxySettings.tag` 指向本机 `11111` 的 HTTP 出站。于是 `11119` 向 `11111` 请求连接 **B 的 VMess 服务地址和端口**。这一步发生在 Windows 回环接口上。
3. `11111` 通过自己的 VMess 连接，请 A 打开到 B 的 TCP 连接。`11119` 沿这条通道与 B 通信，B 再打开到 `chatgpt.com:443` 的连接。Codex 的 HTTPS/WebSocket 流量和响应都沿已建立的通道传输。[V2Fly 出站代理配置](https://www.v2fly.org/config/outbounds.html#proxysettingsobject)

ai122 上用 systemd 启动参数核实了 `v2ray@new` 加载的配置，远端 Codex 后端进程的代理环境和活动连接也都指向 **ai122 自己的** `11119`。Windows 和 ai122 各自完成整条链路。两台机器配置的 B 地址相同，服务端口和认证有差异，实测对目标站呈现相同的出口 IP。

#### 大请求为何受益于中转

在同一台 Windows 上固定 B、认证和目标站，仅更换抵达 B 的方式。小请求每条路径各 4 次，大上传使用同一份 2,400,000 字节的合成数据，按直连、中转、中转、直连的顺序测试。

| 当晚实测 | Windows 直接连 B | Windows 经 A 抵达 B |
| --- | --- | --- |
| 无认证 GET 到 Codex Responses 路径 | 4/4 收到预期的 405，0.38–2.54 秒 | 4/4 收到预期的 405，0.37–1.70 秒 |
| 向 Cloudflare 上传 2.4 MB | 两次均已完成 TLS，48 秒仍未收到 HTTP 响应 | 两次均收到 HTTP 200，1.93 和 2.14 秒 |
| 已登录的 Codex，输入同一张 2.41 MB 合成图片并要求简短回复 | 110 秒内未完成 | 19.49 秒完成 |

另一次 34 秒的直连上传，在 **Windows → B** 的物理 TCP 套接字上测得 65,495 字节重传、25 个重传超时事件，拥塞窗口多次降至一个报文段（1,440 字节）。应用能迅速把数据交给本机代理，外层 TCP 仍可能反复重传。这些计数能定位到这段连接，区分正向数据丢失与回程 ACK 丢失还需要对端观测。[Windows TCP_INFO_v0 字段定义](https://learn.microsoft.com/en-us/windows/win32/api/mstcpip/ns-mstcpip-tcp_info_v0)

切换后，Windows 的生产端口四次上传全部成功，耗时 1.97–18.88 秒，其中一次共 17.81 秒，到完成 TLS 时已过去 16.33 秒。ai122 的生产端口两次上传均成功，耗时 2.25 和 2.65 秒。最终用两个旧会话各自的原登录和历史创建临时副本，分别在 12.34 和 13.85 秒完成回合。这两项验收均从测试进程启动计至回合结束。

#### 直接使用前置节点，或者合并本机转发，能快多少？ {#codex-proxy-alternatives}

**目前保留 `11119` 经 A 抵达 B 作为默认路径。** 直接让 Codex 使用 `11111` 会省掉公网节点 B，目标站也会看到 A 的出口。为了衡量这个取舍，在同一台 Windows 上交错测试了两种入口。

| 11 月 25 日晚的对照 | 当前 `11119`，经 A 从 B 出口 | 直接使用 `11111`，从 A 出口 |
| --- | --- | --- |
| 2.4 MB 合成上传，各 3 次的中位数 | 2.18 秒 | 1.50 秒 |
| Codex models 的无认证 GET，各 2 次，均返回预期的 401 | 0.50、0.55 秒 | 0.85、0.79 秒 |
| 同一账号、模型、2.41 MB 合成图片和指令，各 2 个临时 Codex 回合 | 12.55、15.16 秒 | 22.57、12.26 秒 |

四个回合都完成并返回了要求的 `OK`。回合耗时包含 CLI 启动、请求传输和服务端处理，测试顺序为 A 出口、B 出口、B 出口、A 出口。A 的测速站上传较快，也有一次最快的真实回合，但这组样本不足以证明换出口会稳定缩短 Codex 的等待时间。

若必须保留 B 的出口，另一个选择是让同一个 V2Ray 进程承载 A、B 两个 VMess 出站，用标签在进程内把到 B 的连接交给 A。这样省去本机的回环 HTTP CONNECT，公网仍经过 A 和 B。用临时实例验证了出口 IP 相同，交错上传各 3 次，单进程为 1.79–2.61 秒（中位数 1.98 秒），现有双进程为 1.85–2.32 秒（中位数 2.16 秒）。两组范围重叠，暂时没有为性能迁移生产配置的依据。

若要进一步减少偶发的长等待，可固定 B、请求大小和目标站，在出现卡顿的时段比较几个可用前置节点。记录大请求成功率和最慢样本，同时区分耗时集中在 TLS 握手还是握手之后。若 Windows 到 B 的直连日后恢复，也可以先用隔离探针验证，在多个时段都能稳定传完大请求后再省去 A。

#### 复测 Windows 的 Codex 代理

在仓库根目录用 Windows PowerShell 5.1 运行。诊断工具会在临时回环端口测试原上游的直连和中转，生产服务可继续工作。每轮每路上传 2.4 MB 合成数据，输出包括 HTTP 状态、耗时和直连套接字的重传统计。任一路上传失败时，命令返回非零状态。

```powershell
$ownerId = (Get-NetTCPConnection -State Listen -LocalAddress 127.0.0.1 -LocalPort 11119).OwningProcess
$v2rayDir = Split-Path -Parent (Get-Process -Id $ownerId).Path
python docs/notes/scripts/v2ray_windows_diagnose.py --dir "$v2rayDir" --rounds 2 --timeout 48
```

切换工具适配本例的 V2Ray 5、`config_vmiss.json` 和 `launch_vmiss.bat`。它从监听进程识别安装目录。以下命令依次查看当前模式、验证候选中转、应用中转。

```powershell
$tool = '.\docs\notes\scripts\v2ray_11119_route_windows.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool test-relay
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool relay
```

`relay` 会在隔离端口预检，保存当前用户专用的原配置备份，再短暂重启负责 `11118/11119` 的实例。开机快捷方式仍加载同一配置文件。切换后会在生产 `11119` 上验证 Codex 路径和 2.4 MB 上传，失败时尝试恢复原配置与监听器。要评估恢复直连，可先运行 `test-direct`，确认实际表现后再运行 `direct`。

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
