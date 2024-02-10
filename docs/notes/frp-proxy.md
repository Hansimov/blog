# Use FRP proxy to forward network traffic

## Background
* Machine **PRIVATE** has **limited** access to public network.
* Machine **PUBLIC** has **full** access to publick network.

## Target
* Enable PRIVATE to visit public network with same access with PUBLIC.

## Solution
Download related version of FRP, both in PRIVATE and PUBLIC:
* https://github.com/fatedier/frp/releases
* NOTE: In my personal case, **v0.48.0 works well**, while **v0.50.0 fails**.

For Linux, use:
```sh
wget https://github.com/fatedier/frp/releases/download/v0.48.0/frp_0.48.0_linux_amd64.tar.gz
tar xvf frp_0.48.0_linux_amd64.tar.gz
```

For Windows, download:
* https://github.com/fatedier/frp/releases/download/v0.48.0/frp_0.48.0_windows_amd64.zip


Use PUBLIC as Client and PRIVATE as Server.
* **Note: Do not confuse the meanings of 'server' and 'client' here with conventions.**

Use `ifconfig` to get IP.

Set `frpc.ini` in PUBLIC (Client):
```ini
[common]
server_addr = 10.*.*.215  ; IP of PRIVATE (Server)
server_port = 9999        ; Port of FRP connection

[http_proxy]
type = tcp
remote_port = 11111            ; Port of localhost in PRIVATE (Server)
local_ip = proxy-*.<corp>.com  ; [Optional] IP which has full access to public network
local_port = 912               ; [Optional] Port related to above IP
; plugin = http_proxy          ; If no above local settings, this line should be added to make it work
```

Run in PUBLIC:
```sh
# Windows
.\frpc.exe -c frpc.ini

# Linux
./frpc -c frpc.ini
```

Set `frps.ini` in PRIVATE (Server):
```ini
[common]
bind_port = 9999 ; Port of FRP connection, same to PUBLIC
```

Run in PRIVATE:
```sh
# Windows
.\frps.exe -c frps.ini

# Linux
./frps -c frps.ini
```

Now PRIVATE has same access to network of PUBLIC.

You can use `localhost:11111` (or `http://localhost:11111` in some case) as proxy in PRIVATE to visit network.

```sh
curl --proxy "127.0.0.1:11111" http://ifconfig.me
# Should output the Public IP of PUBLIC
```

## Possible issues
You may encounter some issues with frpc in PUBLIC like:
```sh
DialTcpByHttpProxy error, StatusCode [503]
```

Just check your proxy in env:
```sh
env | grep proxy
```

And unset them (`unset` in bash and `unsetenv` in csh):
```sh
# tsh:
unsetenv http_proxy
unsetenv https_proxy
unsetenv no_proxy


# bash:
unset http_proxy
unset https_proxy
unset no_proxy
```

And rerun `./frpc -c frpc.ini` will work.

## References
* fatedier/frp: A fast reverse proxy to help you expose a local server behind a NAT or firewall to the internet.
  * https://github.com/fatedier/frp
  
* 使用frp为内网服务器代理上网 | 一颗栗子球
  * https://shaoyecheng.com/uncategorized/2021-05-28-使用frp为内网服务器代理上网.html