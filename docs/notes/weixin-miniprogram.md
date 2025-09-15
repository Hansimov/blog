# 微信小程序开发

## 申请、注册、下载工具

::: tip 微信官方文档·小程序：起步 / 开始 / 申请账号
* https://developers.weixin.qq.com/miniprogram/dev/framework/quickstart/getstart.html

小程序注册
* https://mp.weixin.qq.com/wxopen/waregister?action=step1

微信开发者工具下载地址与更新日志
* https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html
:::

需要注意的是：
- 每个邮箱仅能申请一个小程序
- 该邮箱要求：未被微信公众平台注册，未被微信开放平台注册，未被个人微信号绑定

需要依次完成：
- 小程序信息
- 小程序类目
- 小程序备案
- 微信认证

## 消息推送

::: tip 微信官方文档·小程序：基础能力 / 网络 / 使用说明
* https://developers.weixin.qq.com/miniprogram/dev/framework/ability/network.html

微信官方文档·小程序：基础能力 / 服务端能力 / 消息推送 / 开发者服务器接收消息推送
* https://developers.weixin.qq.com/miniprogram/dev/framework/server-ability/message-push.html

微信官方文档·小程序：接口调用凭证 / 获取接口调用凭据
* https://developers.weixin.qq.com/miniprogram/dev/OpenApiDoc/mp-access-token/getAccessToken.html

微信官方文档·小程序：服务端 API / 获取接口调用凭证 / getAccessToken
* https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/miniapp/openapi/getaccesstoken.html

微信开放平台调试工具：消息推送调试
* https://developers.weixin.qq.com/apiExplorer?type=messagePush
:::

首先需要拥有一个服务器域名，可参考：
- [网站搭建和域名解析](./website-dns)
- [使用 Cloudflare Tunnel 将本地服务端口连接到公网域名](./cf-tunnel)

获取 AcessToken：
- `https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=...&secret=...`
- 这里的 `appid` 和 `secret` 也即小程序的 `AppID` 和 `AppSecret`（需要点击生成）。

然后实现加密接口（fastapi），再用 CF Tunnel 将本地端口映射到公网域名。
- 调试工具：https://developers.weixin.qq.com/apiExplorer?type=messagePush

最后需添加域名，在小程序的 `开发与服务 > 开发管理` 页面：
- 打开 https://mp.weixin.qq.com
- 确认已经生成 `AppSecret`
- 添加服务器域名
- 消息推送：添加 URL，设置 Token 和 EncodingAESKey，消息加密模式（安全模式），数据格式（JSON）
