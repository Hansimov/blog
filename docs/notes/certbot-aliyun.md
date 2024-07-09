# 使用 certbot 为阿里云域名生成证书

## 阿里云申请 AccessKey

申请主账号的 AccessKey，包含 `AccessKeyId` 和 `AccessKeySecret`：
- https://ram.console.aliyun.com/manage/ak

复制保存。

需要注意的是，在 RAM 控制台申请的 AccessKey 在结合 alidns 使用的时候会出现问题。所以要创建主账号的 AccessKey。见下面这个 Issue：

::: warning [debug] alidns 运行失败 · Issue #167 · NewFuture/DDNS
  * https://github.com/NewFuture/DDNS/issues/167
:::

不过还是把在 RAM 里申请的链接放在下面，以备不时之需：

::: tip 阿里云 RAM 控制台
* https://ram.console.aliyun.com

创建阿里云AccessKey_访问控制(RAM)-阿里云帮助中心
* https://help.aliyun.com/zh/ram/user-guide/create-an-accesskey-pair
:::

## 安装 aliyun 命令行工具

```sh
wget https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz
tar xzvf aliyun-cli-linux-latest-amd64.tgz
sudo cp aliyun /usr/local/bin
```

## 安装 alidns

```sh
wget https://cdn.jsdelivr.net/gh/justjavac/certbot-dns-aliyun@main/alidns.sh
sudo cp alidns.sh /usr/local/bin
sudo chmod +x /usr/local/bin/alidns.sh
sudo ln -s /usr/local/bin/alidns.sh /usr/local/bin/alidns
```

::: tip justjavac/certbot-dns-aliyun: 阿里云 DNS 的 certbot 插件，用来解决阿里云 DNS 不能自动为通配符证书续期的问题
* https://github.com/justjavac/certbot-dns-aliyun
:::

## 使用 aliyun 配置凭证信息

```sh
aliyun configure set --profile akProfile --mode AK --region cn-hangzhou --access-key-id L********************Nn7 --access-key-secret ******************************
```

- `--profile`：配置名称，默认为 `default`
- `--mode`：认证方式，默认为`AK`
- `--region`：（必填）地域 regionID
- `--access-key-id`：（必填）AccessKey ID
- `--access-key-secret`：（必填）AccessKey Secret

查看是否配置成功：

```sh
aliyun configure list
```

输出形如：

```sh
Profile     | Credential | Valid | Region      | Language
------------|------------|-------|-------------|---------
akProfile * | AK:***Nn7  | Valid | cn-hangzhou | en
```

再运行 alidns 测试：

```sh
alidns -h
```

若输出下面内容，表示配置成功：

```sh
ERROR: SDK.ServerError
ErrorCode: InvalidParameter
```

若输出下面内容，表示配置失败：

```sh
ERROR: SDK.ServerError
ErrorCode: Forbidden.RAM
...
Message: User not authorized to operate on the specified resource, or this API doesn't support RAM.
```

这里表示配置的是 RAM 的 AccessKey，在 alidns 中不可用，需要重新[申请主账号的 AccessKey](#阿里云申请-accesskey)。


可以用下面的命令删除已经配置的凭证：

```sh
aliyun configure delete --profile akProfile
```

::: tip 如何在阿里云CLI中配置身份凭证_阿里云CLI(CLI)-阿里云帮助中心
* https://help.aliyun.com/zh/cli/configure-credentials#41e7063556zzq

公有云ECS支持购买的地域和可用区_云服务器 ECS(ECS)-阿里云帮助中心
* https://help.aliyun.com/zh/ecs/product-overview/regions-and-zones
:::

## 申请证书

### 测试申请

以 `blbl.top` 为例：

```sh
certbot certonly -d blbl.top --manual --preferred-challenges dns --manual-auth-hook "alidns" --manual-cleanup-hook "alidns clean" --dry-run
```

- `certonly`: Obtain or renew a certificate, but do not install it
- `-d DOMAINS`: Comma-separated list of domains to obtain a certificate for
- `--manual`: Obtain certificates interactively, or using shell script
- `-preferred-challenges dns`: TBD
- `--manual-auth-hook`: TBD
- `--manual-cleanup-hook`: TBD
- `--dry-run`: Test "renew" or "certonly" without saving any certificates to disk

若测试成功，输出形如：

```sh
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Simulating a certificate request for blbl.top
Hook '--manual-auth-hook' for blbl.top ran with output:
 {
        "RecordId": "90**************16",
        "RequestId": "5******4-****-****-****-************"
 }
Hook '--manual-cleanup-hook' for blbl.top ran with output:
 {
        "RecordId": "90**************16",
        "RequestId": "1******3-****-****-****-************"
 }
The dry run was successful.
```

### 正式申请

去掉 `--dry-run`：

```sh
certbot certonly -d blbl.top --manual --preferred-challenges dns --manual-auth-hook "alidns" --manual-cleanup-hook "alidns clean"
```

- 需要输入邮箱地址
- 同意服务条款
- 选择是否分享邮箱地址

若申请成功，输出形如：

```sh
Account registered.
Requesting a certificate for blbl.top
Hook '--manual-auth-hook' for blbl.top ran with output:
{
    "RecordId": "90**************88",
    "RequestId": "1*******9-****-****-****-************"
}
Hook '--manual-cleanup-hook' for blbl.top ran with output:
{
    "RecordId": "90**************88",
    "RequestId": "7*******B-****-****-****-************"
}

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/blbl.top/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/blbl.top/privkey.pem
This certificate expires on 2024-10-07.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
```

### 在 Nginx 中配置证书

certbot 申请的证书文件默认保存到：

- `/etc/letsencrypt/live/blbl.top/fullchain.pem` （证书链）
- `/etc/letsencrypt/live/blbl.top/privkey.pem` （私钥）

在 Nginx 配置文件中添加：

```nginx
server {
    listen 443 ssl;
    server_name blbl.top;

    ssl_certificate /etc/letsencrypt/live/blbl.top/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/blbl.top/privkey.pem;

    ...
}
```

## 自动续期

添加定时任务：

```sh
crontab -e
```

内容为：

```sh
1 1 */1 * * root certbot renew --manual --preferred-challenges dns --manual-auth-hook "alidns" --manual-cleanup-hook "alidns clean" --deploy-hook "nginx -s reload"
```

- `1 1 */1 * *`：表示每月1日1时1分执行
- `--deploy-hook "nginx -s reload"`：表示在续期成功后自动重启 nginx
