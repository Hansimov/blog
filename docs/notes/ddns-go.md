# 使用 ddns-go 将公网动态 IP 解析到域名

::: tip jeessy2/ddns-go: Simple and easy to use DDNS. Support Aliyun, Tencent Cloud, Dnspod, Cloudflare, Callback, Huawei Cloud, Baidu Cloud, Porkbun, GoDaddy, Namecheap, NameSilo...
* https://github.com/jeessy2/ddns-go

ddns-go 的使用，实现公网 IPv6 下动态域名解析 - DDNS_TendCode
* https://tendcode.com/subject/article/ddns-go/
:::


::: warning 注意：此方法需要访问的客户端也支持 IPv6，否则无法访问解析后的域名。
:::

## 下载、安装和卸载

### 下载

从 GitHub 下载 release 并解压：

```sh
cd ~/downloads
wget https://githubfast.com/jeessy2/ddns-go/releases/download/v6.6.9/ddns-go_6.6.9_linux_i386.tar.gz
tar zxvf ddns-go_6.6.9_linux_i386.tar.gz --one-top-level
cd ddns-go_6.6.9_linux_i386
```

### 安装

```sh
sudo ./ddns-go -s install
```

### 卸载

```sh
sudo ./ddns-go -s uninstall
```

## 服务管理

### 查看状态

```sh
sudo systemctl status ddns-go
```

### 重启服务

```sh
sudo systemctl restart ddns-go
```

### 停止服务

```sh
sudo systemctl stop ddns-go
```

## 命令行参数

`./ddns-go --help`:

```sh
Usage of ./ddns-go:
  -c string
        Custom configuration file path (default "~/.ddns_go_config.yaml")
  -cacheTimes int
        Cache times (default 5)
  -dns string
        Custom DNS server address, example: 8.8.8.8
  -f int
        Update frequency(seconds) (default 300)
  -l string
        Listen address (default ":9876")
  -noweb
        No web service
  -resetPassword string
        Reset password to the one entered
  -s string
        Service management (install|uninstall|restart)
  -skipVerify
        Skip certificate verification
  -u    Upgrade ddns-go to the latest version
  -v    ddns-go version
```

## 配置管理

- 访问 web 页面：
  - `http://<hostname>:9876`
  - 设置用户名密码

- `DNS 服务商`，以阿里云为例：
  - 参考：[阿里云申请 AccessKey](./certbot-aliyun#阿里云申请-accesskey)
  - 访问：https://ram.console.aliyun.com/manage/ak
    - `AccessKeyId`：阿里云 AccessKey ID
    - `AccessKeySecret`：阿里云 AccessKey Secret

- IPv4：
  - `是否启用`：取消勾选

- IPv6：
  - `是否启用`：勾选
  - `获取 IP 方式`：
    - 默认 `通过网卡获取`
    - 应该已经显示了 IPv6 地址，形如：`eno1[240*:...]`
    - IPv6 前缀：电信 `240e`，联通 `2408`，移动 `2409`
  - 查看本机 IPv6 地址：
    - `ip -6 addr | grep "inet6 240"`

- 其他：
  - `禁止公网访问`：取消勾选
  - 用户名和密码

- 确认防火墙已开放 9876 端口
  - `sudo ufw allow 9876`

- 查看阿里云域名解析记录：
  - `https://dns.console.aliyun.com/#/dns/setting/<root.domain>`