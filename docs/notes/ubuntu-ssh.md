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
