# 使用 Cloudflare One (Zero Trust) WARP 组网

## 注册账号，配置 Team

::: tip Get started · Cloudflare One docs
* https://developers.cloudflare.com/cloudflare-one/setup/

:::

确保已经注册了 Cloudflare 账号：
* https://dash.cloudflare.com/sign-up

* 在 Cloudflare One 页面的左侧菜单栏，点击 `Settings`
* 在右边的选项卡中选择 `Team name`
* Edit 设置团队名称，Save 保存

## 【可选】创建账户级别 API token

::: tip Create API token · Cloudflare Fundamentals docs
* https://developers.cloudflare.com/fundamentals/api/get-started/create-token/

API Tokens | Cloudflare
* https://dash.cloudflare.com/profile/api-tokens

Account API tokens · Cloudflare Fundamentals docs
* https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/
:::

进入账户主页：
* https://dash.cloudflare.com/ 
* 选择左侧菜单 `Manage account` > `Account API tokens`
* 点击右侧的 `Create token`
* 点击 `Create Custom Token` 右侧的 `Get started`
* 填写 `Token name`
* 添加 `Permissions`：
  * `Account` > `Cloudflare One Connector: WARP` > `Edit`
  * `Account` > `Cloudflare One Connector: cloudflared` > `Edit`
  * `Account` > `Account: SSL and Certificates` > `Edit`
  * `Account` > `Zero Trust` > `Edit`
  * 注意不要误选成 `Cloudforce One`
* 点击 `Continue to summary`
* 点击 `Create Token`

测试 token 是否可用：

```sh
curl "https://api.cloudflare.com/client/v4/accounts/<your-account-id>/tokens/verify" -H "Authorization: Bearer <your-api-token>"
```

* 将 `<your-account-id>` 替换为账户 ID
* 将 `<your-token>` 替换为刚创建的 token

输出形如：

```json
{"result":{"id":"...","status":"active"},"success":true,"errors":[],"messages":[{"code":10000,"message":"This API Token is valid and active","type":null}]}
```

## 安装 WARP 客户端

::: tip pkg.cloudflareclient.com
* https://pkg.cloudflareclient.com/#ubuntu
:::

添加 cloudflare gpg key：

```sh
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
```

添加 cloudflare apt 源：

```sh
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
```

安装 `cloudflare-warp`：

```sh
sudo apt-get update && sudo apt-get install cloudflare-warp
```

查看是否安装成功：

```sh
which warp-cli
```

## 创建根证书，并激活

::: tip User-side certificates · Cloudflare One docs
* https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/user-side-certificates/
:::

* Cloudflare One > `Traffic policies` > `Traffic settings`
* 在右边的选项中选择 `Certificates`
* 点击下面的 `Generate certificate`
* 会弹出 `Expiration`，默认是 `5 years (recommended)`，可以改成 `Custom` 并设置为 `10000` 天（约为27年5个月）

页面会显示这个新创建的证书，点击右侧的 `⋮`，选择 `Activate` 以激活。过一会会显示 `AVAILABLE`，表示已激活。

## 安装根证书

::: tip Install certificate using WARP · Cloudflare One docs
* https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/user-side-certificates/automated-deployment/

Install certificate manually · Cloudflare One docs
* https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/user-side-certificates/manual-deployment/#linux
:::

使用 WARP 安装证书：

* Cloudflare One > `Team & Resources` > `Devices`
* 在右边的选项卡中选择 `Management` > `Global WARP settings`
* 开启 `Install CA to system certificate store` 右侧的按钮，并 `Confirm`

安装 WARP 客户端（[这里](./cf-warp.md#安装-warp-客户端)），注册设备（[这里](./cf-warp.md#注册设备到-team)）。然后 WARP 会默认下载所有可用的根证书。

更新自定义 CA 证书：

```sh
sudo update-ca-certificates
```

查看证书是否安装成功：

```sh
ls -l /usr/local/share/ca-certificates | grep -E 'managed-warp' || true
```

输出形如：

```sh
lrwxrwxrwx 1 root root   49  1月  5 16:41 managed-warp.crt -> /usr/local/share/ca-certificates/managed-warp.pem
-rw-r--r-- 1 root root 1143  1月  5 16:41 managed-warp.pem
```

* 确保同时存在 `managed-warp.pem` 和 `managed-warp.crt` 的符号链接

## 【可选】设置设备注册权限

::: tip Device enrollment permissions · Cloudflare One docs
https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/deployment/device-enrollment/
:::

* Cloudflare One > `Team & Resources` > `Devices`
* 在右边的选项卡中选择 `Management` > `Device Enrollment`
* 找到 `Device enrollment permissions`，点击右侧的 `Manage`
* 在 `Policies` 选项卡下面，点击 `Add a policy`

会弹出一个新的 `Add policy` 页面：
* 设置 `Policy name`
* `Add rules` 中，在 `Include` (OR) 中，Selector 中选择 `Emails`，Value 中填写允许的邮箱地址
* 点击页面底部的 `Save` 保存
* 此时 `Policies` 页面就会显示这个新添加的策略

启用策略：
* 点击 `Select existing policy`，勾选这个新策略，点击 `Confirm`
* 此时页面 `Policy details` 中会显示已启用的策略，点击右下角的 `Save` 保存

禁用策略：
* 点击 `Select existing policy`，取消勾选这个新策略，点击 `Confirm`

::: tip 为了避免后续的一些潜在的权限问题，可以先不启用策略。
:::

## 注册设备到 Team

::: tip Manual deployment · Cloudflare One docs
* https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/deployment/manual-deployment/#enroll-using-the-cli
:::

```sh
warp-cli registration new <your-team>
```

如果命令行环境不适合打开浏览器，或者不方便登录账户，可以参考 `Troubleshoot missing registration` 中的步骤。

在已经登录了账户的电脑上，用浏览器打开登录页：

* `https://<your-team>.cloudflareaccess.com/warp`
* 这里的 `<your-team>` 替换成上面团队名称
* 填写邮箱地址和收到的验证码
* 登录成功应当显示 `Success!`

然后右键选择 `查看网页源代码`，搜索 `url=com.cloudflare.warp`，找到形如下面的注册链接：

```sh
url=com.cloudflare.warp://<your-team>.cloudflareaccess.com/auth?token=eyJ...
```

复制 `token=` 后面的内容，然后运行下面的命令：

```sh
warp-cli registration token "com.cloudflare.warp://<your-team>.cloudflareaccess.com/auth?token=..."
```

* 如果显示 `Error(401): Unauthorized`，说明 token 已经过期，需要重新获取。刷新页面即可
* 如果显示 `Successs`，表示注册成功

查看注册状态：

```sh
warp-cli registration show
```

查看所属组织：

```sh
warp-cli registration organization
```

删除当前已注册设备：

```sh
warp-cli registration delete
```

