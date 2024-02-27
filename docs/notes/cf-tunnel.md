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

## Setup tunnel

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

::: warning Sometimes connection would be timeout, you might need to use a proxy that is able to access cloudflare.
:::

### Create tunnel


```sh
# cloudflared tunnel create <tunnel-name>
cloudflared tunnel create chat
```

::: tip See: Create tunnel locally (CLI):
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel
:::

::: warning You might encounter following issue:
> failed to create tunnel: Create Tunnel API call failed: REST request failed: Post "https://api.cloudflare.com/client/v4/accounts/0eaac800b72d47966d3858a5a24965d0/cfd_tunnel": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
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
* Useful commands · Cloudflare Zero Trust docs
  * https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/tunnel-useful-commands