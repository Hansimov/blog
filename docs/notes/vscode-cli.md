# 安装 VSCode CLI

## Ubuntu 环境

### 下载，解压
```sh
cd ~/downloads
```
```sh
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
```
```sh
mkdir -p vscode_cli && tar -xf vscode_cli.tar.gz -C vscode_cli
```

### 安装，重命名
```sh
sudo install -m 0755 ./vscode_cli/code /usr/local/bin/vscli
```

### 查看安装情况

查看是否安装成功：

```sh
which vscli
```
```
/usr/local/bin/vscli
```

查看版本：
```sh
vscli --version
```
```
code 1.109.5 (commit 072586267e68ece9a47aa43f8c108e0dcbf44622)
```

## 注册为 systemd service

假设本地的 tunnel 名称为 `xeon`。

### 首次运行，授权

```sh
vscli tunnel --name xeon --accept-server-license-terms
```

选择 `GitHub Account` 登录，浏览器打开 https://github.com/login/device ，输入命令行提示的授权码，确认即可。


### 安装 tunnel service

```sh
systemctl --user daemon-reload
```

```sh
vscli tunnel service install --accept-server-license-terms --name xeon
```
```sh
[2026-02-28 10:38:53] info Successfully registered service...
[2026-02-28 10:38:53] info Successfully enabled unit files...
[2026-02-28 10:38:53] info Tunnel service successfully started
[2026-02-28 10:38:53] info Tip: run `sudo loginctl enable-linger $USER` to ensure the service stays running after you disconnect.
Service successfully installed! You can use `code tunnel service log` to monitor it, and `code tunnel service uninstall` to remove it.
```

### 启用服务

```sh
systemctl --user enable --now code-tunnel.service
```

查看服务状态：
```sh
systemctl --user status code-tunnel.service
```

设置开机启动：

```sh
sudo loginctl enable-linger $USER
```

查看日志：

```sh
vscli tunnel service log
```

<details> <summary>【可选】修改服务配置</summary>

### 【可选】修改服务配置

创建 systemd 的 drop-in 目录，写入 proxy 配置：
```sh
mkdir -p ~/.config/systemd/user/code-tunnel.service.d
```

```sh
cat > ~/.config/systemd/user/code-tunnel.service.d/10-proxy.conf <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:11111"
Environment="HTTPS_PROXY=http://127.0.0.1:11111"
Environment="NO_PROXY=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
```

重新加载服务：

```sh
systemctl --user daemon-reload
```
```sh
systemctl --user restart code-tunnel.service
```

验证配置是否生效：

```sh
systemctl --user show code-tunnel.service -p Environment
```
```
Environment=HTTP_PROXY=http://127.0.0.1:11111 HTTPS_PROXY=http://127.0.0.1:11111 NO_PROXY=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

查看当前的 drop-in 路径：

```sh
systemctl --user show code-tunnel.service -p DropInPaths
```
```
DropInPaths=/home/asimov/.config/systemd/user/code-tunnel.service.d/10-proxy.conf
```

查看当前 drop-in 配置：

```sh
systemctl --user cat code-tunnel.service
```
```
...
# /home/asimov/.config/systemd/user/code-tunnel.service.d/10-proxy.conf
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:11111"
Environment="HTTPS_PROXY=http://127.0.0.1:11111"
Environment="NO_PROXY=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

删除 drop-in 配置：
```sh
rm -f ~/.config/systemd/user/code-tunnel.service.d/*proxy*.conf
```

重新加载服务：

```sh
systemctl --user daemon-reload
```
```sh
systemctl --user restart code-tunnel.service
```

确认环境变量已被移除：

```sh
systemctl --user show code-tunnel.service -p Environment
```
```
Environment=
```

</details>

### 网页访问 tunnel

- https://vscode.dev/tunnel/xeon
- https://vscode.dev/tunnel/xeon/home/asimov/repos

## 常见问题

### GitHub Copilot 的模型没有正常显示

主要原因是 GitHub Copilot 插件没有成功登录。

对于电脑的 Web 端：
- 打开 Settings，在 `User` 和 `Remote [xeon]` 中分别搜索 `proxy`，将 `Http: Proxy` 设为可用高阶模型的代理地址（香港 IP 即可）
- **`User` 的代理设置是必要的**，因为在客户端，vscode.dev 和 GitHub Copilot Chat 都需要在本地使用 GitHub 登录，而这一步必须要代理
- 快捷的设置是 `Ctrl+Shift+P` → `Preferences: Open User Settings (JSON)`，然后添加如下配置：
  ```json
  { "http.proxy": "http://127.0.0.1:11111" }
  ```

对于手机的 Web 端：

<details> <summary>（暂时卡在了 GitHub Copilot，隐藏了一个无效方案）</summary>

- 以 V2rayNG 为例
  - 默认 HTTP 端口为 `10808`（或者可以在 "设置" > "本地代理端口" 中查看），因此需要如下配置：
  ```json
  { "http.proxy": "http://127.0.0.1:10808" }
  ```
  - 同时需要将 "设置" > "追加 HTTP 代理至 VPN" 勾选上

</details>

- 如果是手机端访问，需要将浏览器加入代理路由的应用列表中
- 可以运行 chat diagnostics，查看日志
- 如果 Chrome 浏览器始终有问题，试试用无痕模式访问 vscode.dev

### 使用蓝牙键盘连接到手机时，手机自带输入法总是反复弹出
- 按 F11 进入全屏模式
- 下拉顶部菜单，选择 `配置实体键盘`，然后将 "显示虚拟键盘" 打开再关闭，就能解决这个问题
- 如果又出现了，重复上述步骤即可，重要的是下拉菜单这一步，可以隐藏弹出的手机输入法
- 可以按 shift 键切换中英输入，按大写输入半角符号
