# 使用 Cloudflare Tunnel 将本地服务端口连接到公网域名
## 前置要求

购买一个域名：(例如 **olivaw.space**)

::: tip See: https://www.name.com
:::

注册 cloudflare：

::: tip See: https://www.cloudflare.com/products/tunnel
:::

## 安装 cloudflared

### Windows

下载安装包：
- https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi

双击 .msi 文件安装。

### Linux (Debian)

```sh
curl -L --output cloudflared.deb https://githubfast.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

## 配置 tunnel

### 登录

```sh
cloudflared tunnel login
```

点击命令行的链接，选择列出的域名（**olivaw.space**），然后点击 **Authorize**。

若创建成功，输出形如：

```sh
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
~/.cloudflared/cert.pem
```

::: warning Sometimes connection would be timeout, you might need to use a proxy that is able to access cloudflare.
:::

### 创建 tunnel

```sh
# cloudflared tunnel create <tunnel-name>
cloudflared tunnel create chat
```

若创建成功，输出形如：

```sh
Tunnel credentials written to /home/asimov/.cloudflared/********-****-****-****-************.json.
cloudflared chose this file based on where your origin certificate was found.
Keep this file secret. To revoke these credentials, delete the tunnel.

Created tunnel bili-search with id ********-****-****-****-************
```

::: tip See: Create tunnel locally (CLI):
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel
:::

::: warning You might encounter following issue:
> failed to create tunnel: Create Tunnel API call failed: REST request failed: Post "https://api.cloudflare.com/client/v4/accounts/0eaac800b72d47966d3858a5a24965d0/cfd_tunnel": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
:::

### 列出已有 tunnel

```sh
cloudflared tunnel list
```

### 删除指定 tunn
  
```sh
# cloudflared tunnel delete <tunnel-name>
cloudflared tunnel delete chat
```

### 将 tunnel route 到 DNS 域名

```sh
# cloudflared tunnel route dns <tunnel_name> <subdomain>
cloudflared tunnel route dns chat chat.olivaw.space
```

若成功，输出形如：

```sh
Added CNAME chat.olivaw.space which will route to this tunnel tunnelID=********-****-****-****-************
```

### 在 tunnel 中 run 本地服务端口

```sh
# cloudflared tunnel run --url http://<localhost>:<port> <tunnel_name>
cloudflared tunnel run --url http://127.0.0.1:13333 chat
```

访问 **https://chat.olivaw.space** 即可使用本地服务 **http://127.0.0.1:13333**.


## 参考

* 使用Cloudflare Argo Tunnel快速免公网IP建站
  * https://blog.zapic.moe/archives/tutorial-176.html
* `cloudflared tunnel --help`
* Useful commands · Cloudflare Zero Trust docs
  * https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/tunnel-useful-commands