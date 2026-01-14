# Ubuntu 开启 SSH 服务

## SSH 命令
### 安装

```sh
sudo apt install openssh-server
```

### 启动服务

```sh
sudo systemctl enable ssh --now
```

### 禁用服务

```sh
sudo systemctl disable ssh --now
```

### 开始服务

```sh
sudo systemctl start ssh
```

### 停止服务

```sh
sudo systemctl stop ssh
```

### 检查 SSH 状态

```sh
sudo systemctl status ssh
```

### 查看和关闭 SSH 会话

查看所有会话：

```sh
w
```

查看当前会话：

```sh
tty
```

停掉用户的会话：

```sh
sudo pkill -u <USERNAME> sshd
```

停掉某个 TTY 会话：

```sh
sudo pkill -t <TTY_ID>
```

### 复制文件

```sh
scp asimov@11.24.11.2:/home/asimov/repos/blog/docs/notes/scripts/v2ray-install-release.sh ~/downloads/
```

### 转发端口

在 Windows 的 cmd 运行：

```sh
ssh -L 40101:192.168.31.110:443 root@11.24.11.121
#      ----- -------------- --- ---- ------------
#      |     |              |   |    |
#      |     |              |   |    └─ SSH 服务器地址（通过 Merak 能访问到的远程服务器 IP）
#      |     |              |   └────── SSH 登录用户名（root）
#      |     |              └────────── 远端局域网服务端口：443（HTTPS）
#      |     └───────────────────────── 远端局域网服务 IP：192.168.31.110
#      └─────────────────────────────── 本地监听端口：40101
# 
# ssh -L: 使用 SSH 本地端口转发（local port forwarding），在本机 127.0.0.1:40101 上监听，
#         并把所有访问该端口的流量，通过 SSH 隧道转发到 192.168.31.110:443
```

### 检查防火墙状态

```sh
sudo ufw status 
```

### 删除服务

```sh
sudo apt autoremove openssh-server
```

::: tip See: Ubuntu 22.04上启用SSH服务 - FarmerYang - 博客园
* https://www.cnblogs.com/farmeryang/p/17589064.html

See: 如何在Ubuntu 22.04 LTS上安装/开启SSH协议 - 知乎
* https://zhuanlan.zhihu.com/p/512937312
:::

## 网络信息命令

### 查看 IP 地址

```sh
ip addr | grep inet
```

### 查看本机机器名

```sh
hostname
```

### Windows 扫描局域网机器

```sh
arp -a
```