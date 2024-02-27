# Use Cloudflare Tunnel to expose local server to public network
## Preliminaries

Buy a domain: (e.g., **olivaw.space**)

::: tip See: https://www.name.com
:::

Register cloudflare:

::: tip See: https://www.cloudflare.com/products/tunnel
:::

## Install cloudflared

#### Windows (64-bit)

Download installer: https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi

Install by double clicking .msi file.

#### Linux (Debian) (64-bit)

```sh
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

## Create tunnel

### Login

```sh
cloudflared tunnel login
```

Click the link in the command line, and click the listed domain (**olivaw.space**), then click **Authorize**.

If successful, the console would show:

```sh
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
~/.cloudflared/cert.pem
```

::: tip Sometimes there would be timeout of the connection, you might need to switch to another proxy that is able to access cloudflare.
:::

### Create tunnel

#### Method 1: CLI - [Recommended]

```sh
# cloudflared tunnel create <tunnel-name>
cloudflared tunnel create chat
```

::: tip See: Create tunnel in remote (Dashboard):
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel
:::

#### Method 2: Dashboard

Go to CF index dash:

**Sidebar** > **Zero Trust** > **Networks** > **Tunnels** > **Create a tunnel**

- Select your connector: **Cloudflared**
- Name your tunnel: **chat**
- Save tunnel

::: tip See: Create tunnel locally (CLI):
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel
:::


### Route tunnel to dns domain

```sh
# cloudflared tunnel route dns <tunnel_name> <subdomain>
cloudflared tunnel route dns chat chat.olivaw.space
```

### Run local service in tunnel

```sh
# cloudflared tunnel run --url http://<localhost>:<port> <tunnel_name>
cloudflared tunnel run --url http://127.0.0.1:13333 chat
```

Now you can visit **https://chat.olivaw.space** to access the local service running on **http://127.0.0.1:13333**.


## References

* 使用Cloudflare Argo Tunnel快速免公网IP建站
  * https://blog.zapic.moe/archives/tutorial-176.html
* `cloudflared tunnel --help`
