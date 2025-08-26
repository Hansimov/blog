# 使用 FRP 反向代理

::: tip fatedier/frp at v0.58.1
  * https://github.com/fatedier/frp/tree/v0.58.1?tab=readme-ov-file#example-usage
:::

## 场景

- Machine_L 是本地(Local)机器，没有公网 IP
- Machine_R 是远程(Remote)机器，有公网 IP

现在希望当访问 `[R_IP]:[R_PORT]` 时，提供的是 Machine_L 中 `localhost:[L_PORT]` 的服务。

## 下载 FRP 并解压

国内服务器：

```sh
wget https://githubfast.com/fatedier/frp/releases/download/v0.58.1/frp_0.58.1_linux_amd64.tar.gz && tar xvf frp_0.58.1_linux_amd64.tar.gz
```

国外服务器：

```sh
wget https://github.com/fatedier/frp/releases/download/v0.58.1/frp_0.58.1_linux_amd64.tar.gz && tar xvf frp_0.58.1_linux_amd64.tar.gz
```

## 配置远程机器 R 的 frps.toml

```ini
bindPort = 7000
auth.token = "******"
```

启动 frps：

```sh
./frps -c frps.toml
```

## 配置本地机器 L 的 frpc.toml

```ini
serverAddr = "x.x.x.x"
serverPort = 7000
auth.token = "******"

[[proxies]]
name = "ANY_NAME"
type = "tcp"
localIP = "127.0.0.1"
localPort = 9000
remotePort = 29000
```

- `serverAddr` 是远程机器 R 的公网 IP
- `localPort` 是本地机器 L 上的服务端口，`remotePort` 是远程机器 R 上的服务端口
- `serverPort` 是远程机器 R 上 frps 的绑定端口 (bindPort)，默认是 7000
- `auth.token` 是认证口令，frpc 和 frps 需要相同

启动 frpc：

```sh
./frpc -c frpc.toml
```
