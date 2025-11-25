# PVE 代理转发到 VM

场景：服务器 pve（宿主机）已经配置好了代理（`http://127.0.0.1:11111`），其创建的 ai122（虚拟机）在访问自己的 `http://127.0.0.1:11111` 时，希望流量能够通过 pve 的代理转发出去。

## 确保在 PVE 上已经配置好 v2ray 代理

参考：
- [一键安装 v2ray](./v2ray.md#一键安装)
- [下载 geoip 和 geosite](./v2ray.md#下载-geoip-和-geosite)
- [配置 client 的 config.json](./v2ray.md#配置-client-的-configjson)
- [运行 client](./v2ray.md#运行-client)
- [运行多个 v2ray 服务](./v2ray.md#运行多个-v2ray-服务)

## 查看 PVE IP

一般虚拟机都挂在 vmbr0 上：（如果不同，则替换成对应的网桥名称）

```sh
ip addr show vmbr0
```

或者如果已经知道 pve 在 `192.168.31.x` 网段：

```sh
ip addr | grep -B2 -i "192.168"
```

可以看到一行这样的信息：

```sh
inet 192.168.31.103/24 scope global vmbr0
```

那么我们认为 `PVE_IP` 为 `192.168.31.103`。

## 在 PVE 中用 socat 转发 PVE_IP 的端口到 127.0.0.1

```sh
# root@pve
apt install -y socat
```

```sh
PVE_IP=192.168.31.103
# 将 PVE_IP:11111 转发到 PVE 本机 127.0.0.1:11111
socat TCP-LISTEN:11111,bind=$PVE_IP,reuseaddr,fork TCP:127.0.0.1:11111 &
# 将 PVE_IP:11119 转发到 PVE 本机 127.0.0.1:11119
socat TCP-LISTEN:11119,bind=$PVE_IP,reuseaddr,fork TCP:127.0.0.1:11119 &
```

## 在 VM 中验证 PVE 是否正常转发

在 VM 中运行：

```sh
curl http://192.168.31.103:11111
```

如果没有任何输出，就表示成功。

否则会出现下面的报错：

```sh
curl: (7) Failed to connect to 192.168.31.103 port 11111 after 0 ms: Connection refused
```

或者运行：

```sh
curl --proxy http://192.168.31.103:11111 http://ifconfig.me/ip && echo ""
```

应当输出一个公网 IP。

## 【暂不可用】在 VM 中把 127.0.0.1:11111/11119 转成 PVE 中的对应端口

```sh
# asimov@vm
PVE_IP=192.168.31.103
# 所有发往 127.0.0.1:11111 的 TCP 连接，重定向到 PVE_IP:11111
sudo iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 11111 -j DNAT --to-destination $PVE_IP:11111
# 所有发往 127.0.0.1:11119 的 TCP 连接，重定向到 PVE_IP:11119
sudo iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 11119 -j DNAT --to-destination $PVE_IP:11119
```

添加 SNAT/MASQUERADE 规则：

```sh
# asimov@vm
DEV=$(ip route | awk '/default/ {print $5; exit}')
sudo iptables -t nat -A POSTROUTING -o "$DEV" -p tcp -d $PVE_IP -m multiport --dports 11111,11119 -j MASQUERADE
```

查看 NAT 规则：

```sh
sudo iptables -t nat -L OUTPUT -n -v
sudo iptables -t nat -L POSTROUTING -n -v
```

输出形如：

```sh
Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts  bytes  target     prot  opt  in  out      source     destination
   15    900  DNAT       tcp   --   *   *        0.0.0.0/0  127.0.0.1      tcp dpt:11111 to:192.168.31.103:11111
    0      0  DNAT       tcp   --   *   *        0.0.0.0/0  127.0.0.1      tcp dpt:11119 to:192.168.31.103:11119

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts  bytes  target     prot  opt  in  out      source     destination
    0      0  MASQUERADE  tcp   --   *  enp6s18  0.0.0.0/0  192.168.31.103  multiport dports 11111,11119
```

删除规则：

```sh
sudo iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport 11111 -j DNAT --to-destination $PVE_IP:11111
sudo iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport 11119 -j DNAT --to-destination $PVE_IP:11119
sudo iptables -t nat -D POSTROUTING -o "$DEV" -p tcp -d $PVE_IP -m multiport --dports 11111,11119 -j MASQUERADE
```

## 在 VM 中用 socat 转发 PVE_IP 的端口到本地

```sh
sudo apt install -y socat

PVE_IP=192.168.31.103
sudo socat TCP-LISTEN:11111,bind=127.0.0.1,reuseaddr,fork TCP:$PVE_IP:11111 &
sudo socat TCP-LISTEN:11119,bind=127.0.0.1,reuseaddr,fork TCP:$PVE_IP:11119 &
```

## 验证 VM 中的代理是否生效

```sh
curl --proxy http://127.0.0.1:11111 http://ifconfig.me/ip && echo ""
```