# 指定分配网段内任意 IPv6 作为出口 IP

::: tip 谁不想要 2^64 个 IP 的代理池 ？ - zu1k
* https://zu1k.com/posts/tutorials/http-proxy-ipv6-pool/

基于ip6tables构建随机出口 - Type Boom
* https://www.typeboom.com/archives/112/

利用 IPV6 绕过B站的反爬 | yllhwa's blog
* https://blog.yllhwa.com/2022/09/05/利用IPV6绕过B站的反爬/

创建一个自己的 IPv6 代理池 (ndppd + openresty) - 企鹅大大的博客
* https://qiedd.com/1927.html

IPv6地址分配统计 - 运营商·运营人 - 通信人家园 - Powered by C114
* https://www.txrjy.com/thread-1088343-1-1.html

ipv6攻击视角 - r0fus0d 的博客
* https://r0fus0d.blog.ffffffff0x.com/post/ipv6/#如果你ipv6地址被封了如何更改
:::

## 查看 ipv6 地址

```sh
ip -6 addr show scope global
```

输出形如：

```sh{2,4,6}
2: eno1: <BROADCAST,MULTICAST,ALLMULTI,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 240?:????:????:????:abcd:1234:5678:90ab/64 scope global temporary dynamic
       valid_lft 258952sec preferred_lft 85972sec
    inet6 240?:????:????:????:1234:5678:abcd:1124/64 scope global temporary deprecated dynamic
       valid_lft 258952sec preferred_lft 0sec
    inet6 240?:????:????:????:7890:3456:abcd:0101/64 scope global dynamic mngtmpaddr noprefixroute
       valid_lft 258952sec preferred_lft 172552sec
```

可以看到，`240?:????:????:????::/64` 是分配到的 ipv6 网段。

三大运营商的 ipv6 地址开头：
- 中国联通：`2408`
- 中国移动：`2409`
- 中国电信：`240e`

## 添加路由

将上面的获得的 ipv6 网段添加到路由表中：

```sh
sudo ip route add local 240?:????:????:????::/64 dev eno1
```

- 将 `240?:????:????:????::/64` 替换为实际的 ipv6 网段
- 将 `eno1` 替换为实际的网卡名称
- 这里的 `dev` 是 `device` 的缩写，表示指定网络接口设备

### 查看路由

```sh
ip -6 route show
```

形如：

```sh
::1 dev lo proto kernel metric 256 pref medium
240?:????:????:???::/64 dev eno1 proto ra metric 100 pref medium
240?:????:????:???::/60 via fe80::1 dev eno1 proto ra metric 100 pref high
fe80::/64 dev ????? proto kernel metric 256 pref medium
fe80::/64 dev eno1 proto kernel metric 1024 pref medium
default via fe80::1 dev eno1 proto ra metric 100 pref medium
```

如果只想显示公网地址，可以过滤掉包含 `fe80::` 和 `lo` 的地址：

```sh
ip -6 route show | grep -v 'fe80::' | grep -v 'lo'
```

输出形如：

```sh
240?:????:????:???::/64 dev eno1 proto ra metric 100 pref medium
```

## 启用 ip_nonlocal_bind

```sh
sudo nano /etc/sysctl.conf
```

在文件末尾添加内容并保存：

```sh
net.ipv6.ip_nonlocal_bind = 1
```

使配置生效：

```sh
sudo sysctl -p
```

## 安装 ndppd

```sh
sudo apt install ndppd
```

### 配置 ndppd

```sh
sudo nano /etc/ndppd.conf
```

添加内容：

```lua{2,6}
route-ttl 30000
proxy eno1 {
    router no
    timeout 500
    ttl 30000
    rule 240?:????:????:???::/64 {
        static
    }
}
```

- 将 `eno1` 替换为实际的网卡名称
- 将 `240?:????:????:????::/64` 替换为实际的 ipv6 网段

### 启动 ndppd

```sh
sudo systemctl start ndppd
```

设置开机自启：

```sh
sudo systemctl enable ndppd
```

## 测试出口地址

随机选择一个同网段下的 ipv6 地址，测试出口 IP：

```sh
curl --int 240?:????:????:????:abcd:9876:5678:0123 http://ifconfig.me/ip
```

- `--int` 是 `--interface` 的缩写，用于指定出口 IP

如果之前的步骤都正确，输出的 ipv6 地址应该和 `--int` 指定的相同，形如：
    
```sh
240?:????:????:????:abcd:9876:5678:0123
```

## 网段变更

如果光猫重启或者断电，可能会导致 ipv6 网段变更，需要重新添加路由：

```sh
sudo ip route add local 240x:xxxx:xxxx:xxxx::/64 dev eno1
```

- 这里的 `240x:xxxx:xxxx:xxxx::/64` 是新的 ipv6 网段

重新配置 ndppd：

```sh
sudo nano /etc/ndppd.conf
```

将 `rule 240?:????:????:????::/64` 替换为新的 ipv6 网段：

```lua
route-ttl 30000
proxy eno1 {
    router no
    timeout 500
    ttl 30000
    rule 240x:xxxx:xxxx:xxxx::/64 {
        static
    }
}
```

重启 ndppd：

```sh
sudo systemctl restart ndppd
```


## Python 示例

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/ip_tester.py
:::

<details>

<summary><code>ip_tester.py</code></summary>

<<< @/notes/scripts/ip_tester.py

</details>

运行：

```sh
# pip install netifaces requests tclogger
python ip_tester.py
```

输出形如：

```sh{3,5,7,9,11}
> IPv6 prefix: [240?:????:????:????] (/64)
  > Set: [ipv4]
  * Get: [???.???.???.???]
  > Set: [240?:????:????:????:f618:ad3a:fd1a:f0d0]
  * Get: [240?:????:????:????:f618:ad3a:fd1a:f0d0]
  > Set: [240?:????:????:????:410b:9770:6504:de53]
  * Get: [240?:????:????:????:410b:9770:6504:de53]
  > Set: [240?:????:????:????:b05b:87b2:26b4:15f3]
  * Get: [240?:????:????:????:b05b:87b2:26b4:15f3]
  > Set: [240?:????:????:????:d5bc:58c9:dd74:b45]
  * Get: [240?:????:????:????:d5bc:58c9:dd74:b45]
```
