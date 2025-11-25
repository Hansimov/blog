# 使用 Merak 组网

## Linux 使用 Merak 服务

使用 `linux-amd64` 版本。
- 将文件 `merak-service` 复制到目标路径。
- 将 `<CONFIG_HASH>.yml` 配置文件也放到同一路径下。

注册：

```sh
sudo ./merak-service -service install -config "<FULL_PATH>/<CONFIG_HASH>.yml"
```

运行：

```sh
sudo systemctl enable Merak && sudo systemctl start Merak
# sudo ./merak-service -service run -config "<FULL_PATH>/<CONFIG_HASH>.yml"
```

重启：

```sh
sudo systemctl restart Merak
# sudo ./merak-service -service restart
```

查看服务状态：

```sh
sudo systemctl status Merak
```

## Windows 使用 Merak 服务

使用 `windows-amd64` 版本。
- 将文件 `merak-service.exe` 复制到目标路径。
- 将 `<CONFIG_HASH>.yml` 配置文件也放到同一路径下。

安装：

```sh
merak-service.exe -service install -config "<FULL_PATH>\<CONFIG_HASH>.yml"
```

运行：

```sh
merak-service.exe -service run -config "<FULL_PATH>\<CONFIG_HASH>.yml"
```

启动：

```sh
merak-service.exe -service start
```

## 通过 Merak 访问远程服务器所在局域网的其他服务

用例：
- Merak 的网段是 `11.24.11.x`，远程服务器所在局域网的网段是 `192.168.31.x`。
- 用户个人电脑（Windows）已经通过 Merak 和远程服务器互联。
- 远程服务器的 Merak IP 是 `11.24.11.121`。
- 想要访问的（远程服务器所在局域网的）服务的 IP 是 `192.168.31.101`，端口是 `443`。

那么在 Windows 以管理员身份打开 cmd，运行：

```sh
ssh -L 40101:192.168.31.101:443 root@11.24.11.121
#      ----- -------------- --- ---- ------------
#      |     |              |   |    |
#      |     |              |   |    └─ SSH 服务器地址（通过 Merak 能访问到的远程服务器 IP）
#      |     |              |   └────── SSH 登录用户名（root）
#      |     |              └────────── 远端局域网服务端口：443（HTTPS）
#      |     └───────────────────────── 远端局域网服务 IP：192.168.31.101
#      └─────────────────────────────── 本地监听端口：40101
# 
# ssh -L: 使用 SSH 本地端口转发（local port forwarding），在本机 127.0.0.1:40101 上监听，
#         并把所有访问该端口的流量，通过 SSH 隧道转发到 192.168.31.101:443
```

输入密码即可。

然后在本地访问 `https://127.0.0.1:40101`，就相当于访问远程服务器所在局域网的 `https://192.168.31.101`。


## 常见问题

有时候会变得很卡，试试重启服务：

```sh
sudo systemctl restart Merak
```
