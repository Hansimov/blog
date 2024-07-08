# 搭建网站和域名解析

## 购买域名

Name.com：
- https://www.name.com

阿里云：
- https://wanwang.aliyun.com/domain

下面的例子都以阿里云为例。

## 阿里云实名认证

* 如何完成个人账号实名认证_账号中心(Account)-阿里云帮助中心
  * https://help.aliyun.com/zh/account/user-guide/individual-identities

* 域名实名认证_域名(Domain)-阿里云帮助中心
  * https://help.aliyun.com/zh/dws/user-guide/real-name-verification-for-generic-domain-names

## 购买云服务器

野草云：
- https://www.yecaoyun.com

需要在防火墙中的入站规则里开放 `80` 端口以允许 HTTP 访问：（默认是开放的）
- https://my.yecaoyun.com/clientarea.php?action=productdetails&id=59274
- 类型：`入站`
- 接口：`net0`
- 协议：`tcp`
- 目标端口：`80`

同理，开放 `443` 端口以允许 HTTPS 访问。

## 域名解析

阿里云域名控制台：
- https://dc.console.aliyun.com/next/index#/domain-list/all

添加解析记录。例如有域名 `blbl.top`，那么需要填写以下内容：
- 记录类型：`A`（将域名指向 IPv4 地址）
- 主机记录：`@`（使用根域名，也即 `blbl.top`）
- 记录值：`xx.xx.xx.xx`（云服务器的公网 IP 地址）
- TTL：`10分钟`（解析生效时间，默认即可）

可以通过点击“生效检测”或者 `ping blbl.top` 来测试域名解析是否生效。

## 在云服务器上安装 1panel

```sh
curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
```

配置端口、访问路径、用户名和密码，然后访问 `http://xx.xx.xx.xx:****/<访问路径>`，输入用户名和密码即可。
- 这里的端口需要在云服务器防火墙的入站规则中开放。

::: tip 在线安装 - 1Panel 文档
* https://1panel.cn/docs/installation/online_installation/

1Panel-dev/1Panel: 现代化、开源的 Linux 服务器运维管理面板。
* https://github.com/1Panel-dev/1Panel
:::

## 在 1panel 中配置反向代理

进入 1Panel 控制台，`网站` > `网站`，安装插件 OpenResty。

`创建网站` > `反向代理：`
- 分组：`默认`
- 主域名：`blbl.top`
- 代号：`blbl`
- 代理地址：`http://127.0.0.1:****`（`****` 为服务端口）

## 启用 HTTPS

