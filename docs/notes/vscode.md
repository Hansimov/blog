# VSCode 常见问题

## Remote SSH - 卡在 Download VSCode Server

```sh
ls ~/.vscode-server/bin
```

会列出安装包的哈希值，形如：

```sh
8b3775030ed1a69b13e4f4c628c612102e30a681
```

删除这些已有的安装包：

```sh
rm -rf ~/.vscode-server/bin
```

将对应的哈希填入，下载安装：
- https://update.code.visualstudio.com/commit:{COMMIT_HASH}/server-linux-x64/stable

或者直接在命令行下载：

```sh
wget --content-disposition https://update.code.visualstudio.com/commit:8b3775030ed1a69b13e4f4c628c612102e30a681/server-linux-x64/stable
```

拷贝并解压压缩包，重命名为哈希值：

```sh
cp vscode-server-linux-x64.tar.gz ~/.vscode-server/bin/
cd ~/.vscode-server/bin/
tar -zxf vscode-server-linux-x64.tar.gz
mv vscode-server-linux-x64 8b3775030ed1a69b13e4f4c628c612102e30a681
```

最后在本地 VSCode 重新运行 `Remote SSH: Connect to Host` 即可。

::: tip vs code连接服务器卡在Downloading VS Code Server - MissSimple - 博客园
* https://www.cnblogs.com/c-rex/p/16265570.html
:::

## Remote SSH - Chrome DevTools MCP 仍然使用本地 Node.js

现象：

- 远程服务器上的 Node.js 已升级，但 VS Code 里 `chrome-devtools-mcp` 仍报错：`does not support Node v18.x`
- MCP 日志里出现：`Starting server from LocalProcess extension host`

根因：

- VS Code 里的用户级 MCP 配置默认运行在本地机器。
- 通过 Remote SSH 连接服务器后，只有工作区级 `.vscode/mcp.json` 或远端用户级 MCP 配置，才会运行在远程服务器。
- 所以即使远程服务器已经升级到 Node.js 24，本地 Windows 机器上的旧 Node.js 仍可能被用户级 MCP server 使用。

快速判断：

- 日志中出现 `Starting server from LocalProcess extension host`，说明当前启动的是本地 MCP server。
- 日志中如果显示的是本地旧版本 Node.js，例如 `Node v18.15.0`，也说明实际使用的是本地 Node.js，而不是远程服务器上的 Node.js。

### 推荐做法：改成远端用户级 MCP 配置

如果希望 `chrome-devtools-mcp` 跑在 Remote SSH 连接的服务器上，优先使用远端用户级配置。

在命令面板中执行：

- `MCP: Open Remote User Configuration`

或者直接编辑远端文件：

```sh
~/.vscode-server/data/User/mcp.json
```

内容示例：

```json
{
    "servers": {
        "chromeDevTools": {
            "type": "stdio",
            "command": "/home/<user>/.local/bin/node",
            "args": [
                "/home/<user>/.local/bin/npx",
                "-y",
                "chrome-devtools-mcp@latest",
                "--headless=true",
                "--isolated=true",
                "--executablePath=/usr/bin/google-chrome-stable"
            ]
        }
    }
}
```

说明：

- `command` 和 `args` 里显式指定远端 Node.js / npx 的路径，避免再次回退到旧版本。
- `--executablePath` 显式指定远端 Chrome 的路径。
- `--headless=true` 适合服务器环境。
- `--isolated=true` 会使用独立 profile，减少和日常浏览 profile 的互相影响。

### 可选：强制扩展优先跑在远端

在远端设置中添加：

```json
{
    "remote.extensionKind": {
        "io.github.ChromeDevTools/chrome-devtools-mcp": [
            "workspace"
        ]
    }
}
```

Remote SSH 场景下，这个配置通常可以写到：

```sh
~/.vscode-server/data/Machine/settings.json
```

### 远端环境要求

远端服务器至少需要：

- Node.js `>= 20.19`
- 可用的 Chrome 浏览器

可以先在远端手动验证：

```sh
/home/<user>/.local/bin/node /home/<user>/.local/bin/npx -y chrome-devtools-mcp@latest --headless=true --isolated=true --executablePath=/usr/bin/google-chrome-stable
```

如果启动后不再出现 `Node v18.x` 之类的报错，说明远端运行链路是正常的。

### 本地用户级 MCP 配置没有关掉

即使已经配置好了远端 MCP，如果本地用户级配置里原来还有 `chrome-devtools-mcp`，VS Code 仍可能继续把本地那条 server 启动起来。

处理方法：

1. 在本地 VS Code 执行 `MCP: Open User Configuration`
2. 删除或禁用本地用户配置里的 `chrome-devtools-mcp`
3. 执行 `Developer: Reload Window`
4. 执行 `MCP: List Servers`，确认本地那条 server 已被禁用

如果 reload 之后日志里仍然出现：

```text
Starting server from LocalProcess extension host
```

那就说明本地配置还在生效。

### 远端 `mcp.json` 里出现两条 Chrome DevTools server

有时在 Remote SSH 环境里，手动添加了远端用户级 `chromeDevTools` 配置之后，又通过 MCP Server Gallery 安装过 Chrome DevTools MCP，结果会在远端 `mcp.json` 里同时出现两条 server：

- 一条是手动写的 `chromeDevTools`
- 一条是自动生成的 `io.github.ChromeDevTools/chrome-devtools-mcp`

这样在 `MCP: List Servers` 里就会看到两个 Chrome DevTools 相关条目。

建议：

- 只保留一条明确可控的远端配置
- 优先保留显式指定远端 Node.js 路径的那条
- 删除自动生成、只写了 `npx` 的那条，避免再次走到错误的 Node.js 版本

例如，远端 `mcp.json` 最终保留成这样即可：

```json
{
    "servers": {
        "chromeDevTools": {
            "type": "stdio",
            "command": "/home/<user>/.local/bin/node",
            "args": [
                "/home/<user>/.local/bin/npx",
                "-y",
                "chrome-devtools-mcp@latest",
                "--headless=true",
                "--isolated=true",
                "--executablePath=/usr/bin/google-chrome-stable"
            ]
        }
    }
}
```

### 如果你就是想让它跑在本地

那就不要依赖远程服务器上的 Node.js，而是直接升级本地 Windows 机器上的 Node.js 到 `>= 20.19`，最好升级到 22 或 24。

## .yml 被强制缩进 4 个空格

删掉 `.vscode/settings.json` 中的这行：

```json
"prettier.tabWidth": 4
```

## 在项目中使用网络代理

在项目根目录创建 `.vscode/settings.json`：

```json
{
    "http.proxy": "http://<proxy-server>:<port>",
    "http.proxyStrictSSL": false
}
```

## 通过命令行启动多个窗口

常用参数：

- `--new-window`：打开新窗口（同路径不会重复打开）
- `--reuse-window`：复用已有窗口
- `--folder-uri`：打开文件夹
- `--file-uri`：打开文件

打开本地文件目录：

```sh
code --new-window --folder-uri "file:///E:\********\keys.txt"
code --reuse-window --folder-uri "file:///E:\*****\todos.txt"
```

打开远程文件 ：

```sh
code --new-window --folder-uri "vscode-remote://ssh-remote+asimov@xeon/home/asimov/repos/blog/"
```

## 修改 Windows 下的默认终端为 Cmder

在 `settings.json` 中添加：

```json
{
    // "terminal.integrated.inheritEnv": false,
    // "terminal.integrated.shellIntegration.enabled": false,
    "terminal.integrated.profiles.windows": {
        "Cmder": {
            "path": "C:\\Windows\\System32\\cmd.exe",
            "args": [
                "/K",
                "D:\\cmder\\vendor\\bin\\vscode_init.cmd"
            ]
        }
    },
    "chat.tools.terminal.terminalProfile.windows": {
        "path": "C:\\Windows\\System32\\cmd.exe",
        "args": [
            "/K",
            "D:\\cmder\\vendor\\bin\\vscode_init.cmd"
        ]
    },
    "terminal.integrated.defaultProfile.windows": "Cmder"
}
```

## 新的系统环境变量无法在 cmd 中生效

关闭所有 VSCode 进程，重新打开即可。