# 安装 v2ray


## Ubuntu 安装 v2ray

<details> <summary>（弃用）apt 安装</summary>

### apt 安装

::: warning Ubuntu 22.04 下安装的版本 4.34.0 有问题，例如用 `curl --proxy` 无法正常连接到代理端口
:::


```sh
sudo apt install v2ray
```

下列文件将被安装：
- `/usr/bin/v2ray/v2ray`: V2Ray executable
- `/usr/bin/v2ray/v2ctl`: Utility
- `/etc/v2ray/config.json`: Config file
- `/usr/bin/v2ray/geoip.dat`: IP data file
- `/usr/bin/v2ray/geosite.dat`: domain data file

```sh
# 如果已经这样装了，请卸载
sudo apt autoremove v2ray
```

::: tip See: v2ray 4.34.0-5 in ubuntu22.04 bug · Issue #3005 · v2ray/v2ray-core
- https://github.com/v2ray/v2ray-core/issues/3005

> Did you install V2Ray via the `sudo apt install v2ray` command? I think this V2Ray 4.34.0 version is NOT stable.
> 
> When I downgraded to V2Ray `4.28.2`, the problem was solved.

See: v2ray - Ubuntu PPA
- https://packages.ubuntu.com/search?keywords=v2ray
:::

</details>

<details> <summary>（弃用）解压缩安装</summary>

### 解压缩安装

::: warning 根本无法启动
:::

```sh
wget https://githubfast.com/v2ray/v2ray-core/releases/download/v4.28.2/v2ray-linux-64.zip -O v2ray-linux-64.zip
unzip v2ray-linux-64.zip -d /usr/bin/v2ray
# add to path
export PATH=$PATH:/usr/bin/v2ray
```

::: tip See: v2fly/v2ray-core
- https://github.com/v2fly/v2ray-core

See: Installation - v2fly.org
- https://www.v2fly.org/en_US/guide/install.html#linux-distro-repository

See: Install on Linux - v2ray.com
- https://www.v2ray.com/en/welcome/install.html#install-linux
:::

</details>

### 脚本安装

::: info 修改后的脚本附在文末： [v2ray 完整安装脚本](#v2ray-完整安装脚本)
:::

#### 简单修改

直接拿下面这个脚本安装是不行的，因为 `github.com` 被墙了
- https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh

所以需要修改几个地方：

1. 把脚本中的 `github.com` 替换为 `githubfast.com`，这是一个国内能访问的 github 镜像

   ```sh{2}
   download_v2ray() {
     DOWNLOAD_LINK="https://githubfast.com/v2fly/v2ray-core/releases/download/$RELEASE_VERSION/v2ray-linux-$MACHINE.zip"
     ...
   }
   ```

2. 获取最新版本时需要访问 `api.github.com`，但这个接口没有对应的 `githubfast` 镜像，所以需要注释掉联网部分，手动指定版本号 `v4.28.2`：

      ```sh{17}
      #   # Get V2Ray release version number
      #   TMP_FILE="$(mktemp)"
      #   if ! curl -x "${PROXY}" -sS -i -H "Accept: application/vnd.github.v3+json" -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
      #     "rm" "$TMP_FILE"
      #     echo 'error: Failed to get release list, please check your network.'
      #     exit 1
      #   fi
      #   HTTP_STATUS_CODE=$(awk 'NR==1 {print $2}' "$TMP_FILE")
      #   if [[ $HTTP_STATUS_CODE -lt 200 ]] || [[ $HTTP_STATUS_CODE -gt 299 ]]; then
      #     "rm" "$TMP_FILE"
      #     echo "error: Failed to get release list, GitHub API response code: $HTTP_STATUS_CODE"
      #     exit 1
      #   fi
      #   RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
      #   "rm" "$TMP_FILE"
      #   RELEASE_VERSION="v${RELEASE_LATEST#v}"
          RELEASE_VERSION="v4.28.2" # <--- 添加这里
      ```

3. `download_v2ray()` 函数中要下载验证文件，但是 `.dsgt` 文件在 `githubfast.com` 中也没有，所以要注释掉这部分：

      ```sh
      download_v2ray() {
        DOWNLOAD_LINK="https://githubfast.com/v2fly/v2ray-core/releases/download/$RELEASE_VERSION/v2ray-linux-$MACHINE.zip"
        echo "Downloading V2Ray archive: $DOWNLOAD_LINK"
        if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
          echo 'error: Download failed! Please check your network or try again.'
          return 1
        fi
      #   echo "Downloading verification file for V2Ray archive: $DOWNLOAD_LINK.dgst"
      #   if ! curl -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
      #     echo 'error: Download failed! Please check your network or try again.'
      #     return 1
      #   fi
      #   if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
      #     echo 'error: This version does not support verification. Please replace with another version.'
      #     return 1
      #   fi

      #   # Verification of V2Ray archive
      #   CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' < "${ZIP_FILE}.dgst")
      #   LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
      #   if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
      #     echo 'error: SHA256 check failed! Please check your network or try again.'
      #     return 1
      #   fi
      }
      ```

::: tip See: fhs-install-v2ray/install-release.sh
* https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh
:::

#### 一键安装

其实就是下载和运行上面修改后的脚本：

```sh
wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/scripts/v2ray-install-release.sh -O ./v2ray-install-release.sh && chmod +x ./v2ray-install-release.sh && sudo ./v2ray-install-release.sh
```

#### 下载 geoip 和 geosite

类似上面的，也需要把 `github.com` 替换为 `githubfast.com`：

```sh
sudo wget https://githubfast.com/v2fly/geoip/releases/latest/download/geoip.dat -O /usr/local/share/v2ray/geoip.dat
sudo wget https://githubfast.com/v2fly/domain-list-community/releases/latest/download/dlc.dat -O /usr/local/share/v2ray/geosite.dat
```

::: tip See: fhs-install-v2ray/install-dat-release.sh
- https://github.com/v2fly/fhs-install-v2ray/blob/master/install-dat-release.sh#L19-L25
- https://github.com/v2fly/fhs-install-v2ray/blob/master/install-dat-release.sh#L21-L22
:::

## Windows 安装 v2ray

下载 release：
- https://github.com/v2ray/v2ray-core/releases
- https://github.com/v2fly/v2ray-core/releases/download/v4.31.0/v2ray-windows-64.zip

解压，参考[下面的样例](#config-json-完整样例)修改 `config.json`，然后运行 `v2ray.exe`。

或者创建 `launch_v2ray.bat` 文件，内容如下。双击启动：

```sh
v2ray.exe run --config=config.json
```

若要开机自启，创建快捷方式，发送到下面路径即可：
- `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp`
- 又名：`C:\ProgramData\Microsoft\Windows\[开始]菜单\程序\启动`

## 配置 server 和 client

### 配置 server 的 X-UI

::: tip MHSanaei/3x-ui
https://github.com/MHSanaei/3x-ui
https://github.com/MHSanaei/3x-ui/wiki/Installation#install-in-one-line-recommended
:::

在远端代理服务器安装 x-ui：

```sh
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

安装时会提示设置 `port`。注意需要在防火墙中开放该端口。同时还会生成 Username 和 Password。输出形如：

```sh
Username: **********
Password: **********
Port: 9999
WebBasePath: ******************
Access URL: http://XXX.XXX.XXX.XXX:9999/******************
```

查看设置：

```sh
x-ui settings
```

输出形如：

```sh
The OS release is: ubuntu
[INF] current panel settings as follows:
Warning: Panel is not secure with SSL
hasDefaultCredential: false
port: 9999
webBasePath: /******************/
Access URL: http://XXX.XXX.XXX.XXX:9999/******************/
```

访问 `Access URL`，输入之前命令行的 `Username` 和 `Password`，进入 x-ui 的 dashboard。

在入站列表添加一个 vmess 节点。

这几个信息后面会用到：`address`, `port`, `users` (`id`, `alterId`)。

### 配置 client 的 config.json

::: info 完整的样例附在文末：[`config.json` 完整样例](#config-json-完整样例)
:::

v2ray 默认调用的配置文件位于：
- `/usr/local/etc/v2ray/config.json`

需要修改配置文件中的：
- `inbounds`：`socks` 和 `http` 的 `port`
- `outbounds`: `vnext` > `address`, `port`, `users` (`id`, `alterId`)

::: tip See: Client Configuration - V2Fly.org
- https://www.v2fly.org/en_US/guide/start.html#client
:::


## 运行 client

```sh
sudo systemctl enable v2ray
sudo systemctl start v2ray
```

显示服务状态：

```sh
sudo systemctl status v2ray
```

测试代理：

```sh
curl --proxy http://127.0.0.1:11111 http://ifconfig.me/ip
```

查看日志：

```sh
journalctl -u v2ray.service
```

::: tip See: systemd - How to see full log from systemctl status service? - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/225401/how-to-see-full-log-from-systemctl-status-service
:::

## 运行多个 v2ray 服务

假如想要添加的新服务对应的配置文件为 `config_2.json`。同时不想改动原有的 v2ray 的服务，这时可以采用 `v2ray@service` 这个模板单元。

```sh
cat /etc/systemd/system/v2ray@.service
```

```sh
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray -config /usr/local/etc/v2ray/%i.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
```

```sh
sudo cp /usr/local/etc/v2ray/config.json /usr/local/etc/v2ray/new.json
sudo nano /usr/local/etc/v2ray/new.json
```

修改 `new.json` 中的对应内容：
- `inbounds`: `port` (socks + http)
- `outbounds`: `address`, `port`, `id`

重载 systemd 配置：

```sh
sudo systemctl daemon-reload
```

设置开机自启:

```sh
sudo systemctl enable v2ray@new
```

启动服务：

```sh
sudo systemctl start v2ray@new
```

查看服务状态：

```sh
sudo systemctl status v2ray@new
```

测试新代理：

```sh
curl --proxy http://127.0.0.1:11119 http://ifconfig.me/ip
```

## 附录
### v2ray 完整安装脚本

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/v2ray-install-release.sh
:::

<<< @/notes/scripts/v2ray-install-release.sh


### `config.json` 完整样例

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/v2ray-client-config.json
:::
<<< @/notes/configs/v2ray-client-config.json{7,20,39-40,43}