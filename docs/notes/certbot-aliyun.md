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

## 通过 OpenResty+命令行 申请证书，并定时续期

### 安装 aliyun 命令行工具

```sh
wget https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz
tar xzvf aliyun-cli-linux-latest-amd64.tgz
sudo cp aliyun /usr/local/bin
```

### 安装 alidns

```sh
wget https://cdn.jsdelivr.net/gh/justjavac/certbot-dns-aliyun@main/alidns.sh
sudo cp alidns.sh /usr/local/bin
sudo chmod +x /usr/local/bin/alidns.sh
sudo ln -s /usr/local/bin/alidns.sh /usr/local/bin/alidns
```

::: tip justjavac/certbot-dns-aliyun: 阿里云 DNS 的 certbot 插件，用来解决阿里云 DNS 不能自动为通配符证书续期的问题
* https://github.com/justjavac/certbot-dns-aliyun
:::

### 使用 aliyun 配置凭证信息

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

### 申请证书

#### 测试申请

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

#### 正式申请

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

### 复制证书

certbot 申请的证书文件默认保存到：

- `/etc/letsencrypt/live/blbl.top/fullchain.pem` （证书链）
- `/etc/letsencrypt/live/blbl.top/privkey.pem` （私钥）

如果使用的是 1panel + openresty，各个网站是运行在各自的容器中的，需要进入网站管理界面：
- `http://*.*.*.*:44444/websites/`
- 查看对应的网站
- openresty 的根目录是：`/opt/1panel/apps/openresty/openresty`
- 网站的目录是：
`/opt/1panel/apps/openresty/openresty/www/sites/blbl.top/index`

将上面生成的证书文件拷贝到对应的网站目录下：

```sh
cp /etc/letsencrypt/live/blbl.top/fullchain.pem /opt/1panel/apps/openresty/openresty/www/sites/blbl.top/fullchain.pem
cp /etc/letsencrypt/live/blbl.top/privkey.pem /opt/1panel/apps/openresty/openresty/www/sites/blbl.top/privkey.pem
```

### 导入证书

在 1panel 管理界面中，依次选择 `网站` > `证书` > `上传证书` > `导入方式` > `选择服务器文件`，填入：
- 私钥文件：`/opt/1panel/apps/openresty/openresty/www/sites/blbl.top/privkey.pem`
- 证书文件：`/opt/1panel/apps/openresty/openresty/www/sites/blbl.top/fullchain.pem`

点击网站域名进入设置界面，选择 `HTTPS`，`证书`选择上面的证书即可。

### 续期证书

```sh
nano certbot_renew.sh
```

添加下面的内容：

<<< @/notes/scripts/certbot_renew.sh


```sh
chmod +x certbot_renew.sh
```

运行：

```sh
~/certbot_renew.sh
```

### 定时续期

添加定时任务：

```sh
crontab -e
```

添加内容：

```sh
1 1 */1 * * ~/certbot_renew.sh
```

::: warning 注意：这个定时脚本只会续期证书和复制证书，并不会更新 1panel 中的证书信息。需要手动[导入证书](#导入证书)。
:::

## 通过 OpenResty 面板 申请证书，并自动续期

打开 1panel 的证书面板，`网站` > `证书`：
- `http://*.*.*.*:44444/websites/ssl`

### 创建 Acme 账户

点击 `Acme 账户`，点击 `创建账户`：
- `邮箱`：填写邮箱地址
- `账号类型`：`Let's Encrypt`（默认）
- `密钥算法`：`EC 256`（默认）
- 点击确认

### 创建 DNS 账户
点击 `DNS 账户`，点击 `创建账户`：
- `名称`：`aliyun-dns`（自定义）
- `类型`：`阿里云DNS`（默认）
- `Access Key`：填写申请的 [AccessKeyId](#阿里云申请-accesskey)
- `Secret Key`：填写申请的 [AccessKeySecret](#阿里云申请-accesskey)
- 点击确认

### 申请证书

点击 `申请证书`：
- `主域名`：从网站中获取，比如 `blbl.top`
- `Acme 账户`：选择上面创建的 Acme 账户
- `DNS 账户`：选择上面创建的 DNS 账户
- 勾选 `自动续签`
- 点击确认

等待命令行运行，观察输出日志。成功后，可以在证书列表中看到新申请的证书，且 `自动续签` 一列已经被勾选。

### 配置证书

打开 1panel 的网站面板，`网站` > `网站`：
- `http://*.*.*.*:44444/websites`

选择网站名称（比如 `blbl.top`），进入网站设置界面：
- 选择 `HTTPS` 标签页
- `SSL 选择`：`选择已有证书`
- `Acme 账户`：选择上面创建的 Acme 账户
- `证书`：选择上面申请的证书
- 保存

访问网站，查看证书的颁发日期和截止日期，确认新申请的证书是否应用和生效。