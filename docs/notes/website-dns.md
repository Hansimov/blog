# 网站搭建和域名解析

## 购买域名

Name.com：
- https://www.name.com

阿里云：
- https://wanwang.aliyun.com/domain

### 阿里云实名认证

如果购买阿里云的域名，需要进行实名认证：

* 如何完成个人账号实名认证_账号中心(Account)-阿里云帮助中心
  * https://help.aliyun.com/zh/account/user-guide/individual-identities

* 域名实名认证_域名(Domain)-阿里云帮助中心
  * https://help.aliyun.com/zh/dws/user-guide/real-name-verification-for-generic-domain-names

### 购买云服务器

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

### 在阿里云中添加解析记录

- 阿里云域名控制台：
  - https://dc.console.aliyun.com/next/index#/domain-list/all

点开域名对应的 `管理`，在 `基本信息` 中点击 `修改DNS`。可以设置为阿里云或 Cloudflare 的 DNS 服务器。

Cloudflare 的 DNS 服务器可以在如下地方查看：
  - https://dash.cloudflare.com
  - `DNS` > `Records` > `Cloudflare Nameservers`

DNS 修改完成后，可以通过下面的命令来查看：

```sh
dig NS blbl.top +short
```

输出形如：

```sh
# cloudflare
ns1.cloudflare.com.
ns2.cloudflare.com.
# aliyun
dns12.hichina.com.
dns11.hichina.com.
```

- 阿里云域名解析设置：
  - https://dns.console.aliyun.com/#/dns/domainList

1. 对域名 `blbl.top` 添加根域名解析记录：
   - 记录类型：`A`（将域名指向 IPv4 地址）
   - 主机记录：`@`（使用根域名，也即 `blbl.top`）
   - 记录值：`xx.xx.xx.xx`（云服务器的公网 IP 地址）
   - TTL：`10分钟`（解析生效时间，默认即可）

2. 对域名 `www.blbl.top`：
   - 记录类型：`CNAME`（将域名指向另一个域名）
   - 主机记录：`www`
   - 记录值：`blbl.top`
   - TTL：`10分钟`

可以通过点击“生效检测”或者 `ping blbl.top` 来测试域名解析是否生效。
- https://boce.aliyun.com/detect/dns

### 在 Cloudflare 中添加解析记录

- Cloudflare DNS 控制台：
  - https://dash.cloudflare.com
  - `DNS` > `Records`

1. 对域名 `blbl.top` 添加根域名解析记录：
   - Type：`A`（将域名指向 IPv4 地址）
   - Name：`@`（使用根域名，也即 `blbl.top`）
   - IPv4：`xx.xx.xx.xx`（云服务器的公网 IP 地址）

2. 对域名 `www.blbl.top`：
   - Type：`CNAME`（将域名指向另一个域名）
   - Name：`www`
   - Target：`blbl.top`

::: tip 如果需要后面启用 HTTPS，建议在 Cloudflare 而不是阿里云中添加解析记录，否则会出现证书验证问题。
如果在其中一个已经添加了域名解析记录，需要将另外的一个停掉。
:::

::: tip 如果为了追求速度，不想走 Cloudflare 的代理，可以修改解析记录里的 Proxy Status，也即从 `Proxied` 变成 `DNS only`。不过这时以 HTTPS 方式访问可能会有问题。
* Proxy status - Cloudflare
  * https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/#dns-only-records
:::

## 配置反向代理

### 在云服务器上安装 1panel

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

### 在 1panel 中配置反向代理

进入 1Panel 控制台，`网站` > `网站`，安装插件 OpenResty。

`创建网站` > `反向代理：`
- 分组：`默认`
- 主域名：`blbl.top`
- 代号：`blbl`
- 代理地址：`http://127.0.0.1:****`（`****` 为服务端口）

## 创建证书

<details><summary>（已弃用）1panel 自签证书和 cloudflare 证书</summary>

### 方法1：在 1panel 中创建自签证书

进入 1Panel 控制台，`网站` > `证书` > `自签证书` > `签发证书`，填入域名信息，确认后在证书界面点击 `申请`。

### 方法2：在 Cloudflare 中创建证书

进入账户 Dash 界面，`SSL/TLS` > `Origin Server`：
- 点击 `Create Certificate`，选择默认选项即可，然后点击 `Create`。
- 复制证书和私钥，保存。

</details>

### 方法3：使用 certbot 创建证书

详见：[使用 certbot 为阿里云域名生成证书](./certbot-aliyun)

### 在 1panel 中上传证书

进入 1Panel 控制台，`网站` > `证书` > `上传证书`：

1. 若导入方式为 `粘贴代码`：（适合 Cloudflare 创建的证书）
    - 填入 PEM 格式的证书和私钥，点击确认即可。

2. 若导入方式为 `选择服务器文件`：（适合 certbot 创建的证书）
    - 选择证书和私钥文件路径，点击确认即可。
    - certbot 申请的证书文件默认保存在：
        - 证书文件：`/etc/letsencrypt/live/blbl.top/fullchain.pem`
        - 私钥文件：`/etc/letsencrypt/live/blbl.top/privkey.pem`
    - 1panel 中的证书文件保存在：
        - 证书文件：`/opt/1panel/apps/openresty/openresty/www/sites/blbl.top/fullchain.pem`
        - 私钥文件：`/opt/1panel/apps/openresty/openresty/www/sites/blbl.top/privkey.pem`
## 启用 HTTPS

### 在 1panel 中启用 HTTPS

进入 1Panel 控制台，`网站` > `网站`，点开对应域名 `配置` > `HTTPS`：
- HTTP选项：`访问HTTP自动跳转到HTTPS`
- SSL 选项：`选择已有证书`
- Acme 账户：`手动创建`
- 证书：`*.blbl.top`
- 勾选 `启用HTTPS`，保存即可