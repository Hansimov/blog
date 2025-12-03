# 使用 Tailscale 组网

## 注册账号

注册：https://tailscale.com

## Windows 安装 Tailscale

下载：https://tailscale.com/download/windows

## Ubuntu 安装 Tailscale

### 安装脚本

```sh
curl -fsSL https://tailscale.com/install.sh | sh
```

### 启动服务

注意服务名是 `tailscaled`，后面带个 `d`：

```sh
sudo systemctl enable --now tailscaled
```

查看状态：

```sh
sudo systemctl status tailscaled
```

### 加入 tailnet

在两台设备上分别运行：

```sh
sudo tailscale up
```

这时终端会打印出一段 URL，在浏览器里打开，登录 Tailscale 账号，点击 `Connect`，这台机器就加进了 tailnet。

### 控制台

https://login.tailscale.com/admin/machines

### 关闭 Key 过期

访问控制台页面：
- https://login.tailscale.com/admin/machines

在 MACHINE 最右边的三个小点中，选择 `Disable key expiry`。

这时 MACHINE 下面会显示 `Expiry disabled`。

### 开启 MagicDNS

默认是开启的。可以点开 DNS 管理界面查看：

- https://login.tailscale.com/admin/dns

### 查看服务器 IP

```sh
tailscale ip -4
```

形如 `100.74.x.x` 和 `100.99.x.x`。

```sh
tailscale ip -6
```

形如 `fd7a:x:...` 和 `fd7a:x:...`。

### 配置 UFW

TBD

```sh
sudo ufw allow 41641/udp
sudo ufw reload
```

### 查看连接状态

```sh
tailscale status
```

输出形如：

```sh
100.74.x.x  machine_a <username>@  linux  -
100.99.x.x  machine_x <username>@  linux  -
```

过一段时间，可能是这样的：

```sh
# @machine_a
100.74.x.x  machine_a <username>@  linux  -
100.99.x.x  machine_x <username>@  linux  active; direct [add1:1124:11:2::]:41641, tx 4952188 rx 105610596

#@machine_x
100.74.x.x  machine_a <username>@  linux  active; direct [add1:1124:11:122::]:41641, tx 377567908 rx 4545068
100.99.x.x  machine_x <username>@  linux  -
```

## 确保 ipv6 走物理网卡

### 当前方案：阻断其他 VPN 在 tailscale 链路上的 UDP 流量

```sh
# ipv4
# 阻止出站：本机往 11.24.11.0/24 网段上 41641 端口发 UDP
sudo iptables -A OUTPUT -d 11.24.11.0/24 -p udp --dport 41641 -j REJECT
# 阻止入站：11.24.11.0/24 网段来的、源端口为 41641 的 UDP
sudo iptables -A INPUT  -s 11.24.11.0/24 -p udp --sport 41641 -j REJECT

# ipv6
# 阻止出站：本机往 add1 网段上 41641 端口发 UDP
sudo ip6tables -A OUTPUT -d add1:1124:11:2::/64 -p udp --dport 41641 -j REJECT
# 阻止入站：add1 网段来的、源端口为 41641 的 UDP
sudo ip6tables -A INPUT  -s add1:1124:11:2::/64 -p udp --sport 41641 -j REJECT
```

或者更省心地，直接阻断 VPN 对应的网卡，比如 `merak`：

```sh
# ipv4
sudo iptables  -A OUTPUT -o merak -p udp --dport 41641 -j REJECT
sudo iptables  -A INPUT  -i merak -p udp --sport 41641 -j REJECT

# ipv6
sudo ip6tables -A OUTPUT -o merak -p udp --dport 41641 -j REJECT
sudo ip6tables -A INPUT  -i merak -p udp --sport 41641 -j REJECT
```

重启 tailscaled 服务：

```sh
sudo systemctl restart tailscaled
```

查看状态：

```sh
tailscale status
```

输出应该类似：

```sh
active; direct [240e:...]:41641, tx 904 rx 1096
```

意味着 Tailscale 成功通过物理网卡建立了直连。

### 使用 `iptables-persistent` 持久化规则

```sh
sudo apt install iptables-persistent -y
```

- 安装过程中会提示是否保存当前的 IPv4/IPv6 规则，选择 Yes 即可

确保这几条规则确实在表中：

```sh
sudo iptables  -L OUTPUT -n -v | grep merak
sudo iptables  -L INPUT  -n -v | grep merak
sudo ip6tables -L OUTPUT -n -v | grep merak
sudo ip6tables -L INPUT  -n -v | grep merak
```

删除重复规则：

- `-D` 每执行一次，就删除一条符合条件的规则

```sh
# ipv4
sudo iptables  -D OUTPUT -o merak -p udp --dport 41641 -j REJECT
sudo iptables  -D INPUT  -i merak -p udp --sport 41641 -j REJECT
# ipv6
sudo ip6tables -D OUTPUT -o merak -p udp --dport 41641 -j REJECT
sudo ip6tables -D INPUT  -i merak -p udp --sport 41641 -j REJECT
```

保存当前规则：

```sh
# ipv4
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
# ipv6
sudo sh -c 'ip6tables-save > /etc/iptables/rules.v6'
```

这样，在开机启动时，iptables-persistent 就会自动从这两个文件里 restore 规则。

可以查看是否包含刚刚的规则：

```sh
cat /etc/iptables/rules.v4 | grep merak
cat /etc/iptables/rules.v6 | grep merak
```

### 未来方案：修改 tailscaled 配置

::: warning 该方案似乎还未正式启用，保留以备后用
:::

查看 ipv6 地址：

```sh
ip -6 addr
```

物理网卡形如：`enp100s0f1` 或者 `enp6s18`。

编辑 `tailscaled` 配置文件：

```sh
sudo nano /etc/default/tailscaled
```

添加如下内容：

```sh
TS_ONLY_INTERFACES="enp100s0f1,enp6s18"
```

或者使用黑名单，避免与已有的其他虚拟网卡冲突：

```sh
TS_AVOID_INTERFACES="veth*,br*,merak*,zte*"
TS_AVOID_PREFIX="add1:1124:11:2::/64"
```

重启 tailscaled：

```sh
sudo systemctl daemon-reload && sudo systemctl restart tailscaled
```

查看：

```sh
tailscale status
```

### 备用方案：修改 iptables 规则

::: warning 该方案似乎无效，保留以备后用
:::

#### 备用方案流程

```sh
sudo nano /etc/iproute2/rt_tables
```

添加如下内容：

```sh
41461 tailscale
```

- 这里的 `41461` 是随便选的一个不冲突的数字。

查看当前路由：

```sh
# ipv4
ip route show default
# default via 192.168.1.1 dev enp100s0f1 proto dhcp metric 101

# ipv6
ip -6 route show default
# default via fe80::****:****:****:**** dev enp100s0f1 proto ra metric 101 pref medium
```

使用 `ip route` 添加路由：

```sh
# ipv4
sudo ip route add default via 192.168.1.1 dev enp100s0f1 table tailscale
# ipv6

sudo ip -6 route add default via fe80::****:****:****:**** dev enp100s0f1 table tailscale
```

使用 `iptables` 对 Tailscale 流量 mark：

```sh
# ipv4
sudo iptables  -t mangle -A OUTPUT -p udp --dport 41641 -j MARK --set-mark 0x41

# ipv6
sudo ip6tables -t mangle -A OUTPUT -p udp --dport 41641 -j MARK --set-mark 0x41
```

- 这里的 `0x41` 是随便选的一个不冲突的数字。

使用 `ip rule` 添加规则：

```sh
sudo ip rule add fwmark 0x41 lookup tailscale
```

- 所有被标记为 `0x41` 的流量，都走 `tailscale` 路由表。

此时，内核的路由决策逻辑是：
- 普通流量：不带 mark → 查 main 表（现有的路由，VPN 可以接管默认路由无所谓）
- Tailscale 隧道流量：`UDP/41641` → 打 mark `0x41` → 查 `tailscale` 表 → 只能从物理网卡的默认路由出去

刷新 `ip route` 缓存：

```sh
sudo ip route flush cache
```

重启 `tailscaled` 服务：

```sh
sudo systemctl restart tailscaled
```

查看状态：

```sh
tailscale status
```

查看路由决策：

```sh
ip -6 route get <ipv6_addr> sport 41641 dport 41641
```

#### 复原 iptables 规则

如果想消除该方案的影响，使用下面的步骤还原。

查看 `ip rule`：

```sh
ip rule list
```

输出应该包含下面一行：

```sh
5209:   from all fwmark 0x41 lookup 41461
```

删除该规则：

```sh
sudo ip rule del fwmark 0x41 lookup 41461
```

查看 tailscale 路由表：

```sh
ip route show table 41461
ip -6 route show table 41461
```

删除该路由表：

```sh
sudo ip route flush table 41461
sudo ip -6 route flush table 41461
```

再次查看：

```sh
ip route show table 41461
ip -6 route show table 41461
```

输出应该为空。

查看 mangle 表规则：

```sh
# ipv4
sudo iptables  -t mangle -L OUTPUT -n --line-numbers
# ipv6
sudo ip6tables -t mangle -L OUTPUT -n --line-numbers
```

输出形如：

```sh
# ipv4
Chain OUTPUT (policy ACCEPT)
num  target  prot opt source      destination
1    MARK    udp  --  0.0.0.0/0   0.0.0.0/0     udp dpt:41641 MARK set 0x41

# ipv6
Chain OUTPUT (policy ACCEPT)
num  target  prot opt source      destination
1    MARK    udp      ::/0        ::/0          udp dpt:41641 MARK set 0x41
```

删除规则：

```sh
# ipv4
sudo iptables  -t mangle -D OUTPUT -p udp --dport 41641 -j MARK --set-mark 0x41

# ipv6
sudo ip6tables -t mangle -D OUTPUT -p udp --dport 41641 -j MARK --set-mark 0x41
```

再次查看：

```sh
sudo iptables  -t mangle -L OUTPUT -n --line-numbers
sudo ip6tables -t mangle -L OUTPUT -n --line-numbers
```

输出应该为空。

#### 快速检查是否还原

```sh
# 检查 fwmark
ip rule list | grep -i fwmark

# 检查 tailscale 表是否为空
ip route show table 41461
ip -6 route show table 41461

# 检查 mangle/OUTPUT 里有没有 MARK 0x41
sudo iptables  -t mangle -L OUTPUT -n --line-numbers
sudo ip6tables -t mangle -L OUTPUT -n --line-numbers
```

## 高带宽优化

在两台服务器中均做如下配置。

### 启用 BBR 拥塞控制

```sh
sudo nano /etc/sysctl.d/99-bbr.conf
```

添加如下内容：

```sh
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

参数解释：

- `net.core.default_qdisc`：
  - 设置默认的队列调度算法
  - 是内核里“所有网络设备默认用什么队列算法”的全局开关
  - `= fq`：Fair Queue，公平队列调度器
    - 把不同连接的包分开排队，尽量公平分配带宽
    - 和 BBR 配合效果很好，可以减少队头阻塞，让 BBR 更准确估计瓶颈带宽
- `net.ipv4.tcp_congestion_control`：
  - 选择 TCP 拥塞控制算法
  - `= bbr`：
    - 不是看“丢包”来判断拥塞，而是根据带宽+RTT来估算链路状态
    - 长距离、大带宽链路上吞吐量明显提升，延迟也更稳定

应用配置：

```sh
sudo sysctl --system
```

查看：

```sh
sysctl net.ipv4.tcp_congestion_control
```

输出形如：

```sh
net.ipv4.tcp_congestion_control = bbr
```

### 放大 TCP 缓冲区

适用于大文件长距离。

```sh
sudo nano /etc/sysctl.d/99-tcp-buff.conf
```

添加如下内容：

```sh
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
```

参数解释：

- `net.core.rmem_max`：最大接受缓冲 (receive)，单位为字节
- `net.core.wmem_max`：最大发送缓冲 (write)，单位为字节
- `134217728`：`= 128 * 1024 * 1024`，即 128 MB
  - 允许单个 TCP 连接把缓冲区最多扩到 128MB 的量级
- `net.ipv4.tcp_rmem = 4096 87380 134217728`
  - 最小接受缓冲：4096 字节，即 4 KB
  - 默认接受缓冲：87380 字节，即约 85 KB
  - 最大接受缓冲：134217728 字节，即 128 MB
- `net.ipv4.tcp_wmem = 4096 65536 134217728`
  - 发送缓冲是 65536 字节，即 64 KB

- 对于长距离、大带宽、高延迟的链路，给足缓冲才能尽量跑满带宽

应用配置：

```sh
sudo sysctl --system
```

查看：

```sh
sysctl net.core.rmem_max
```

输出形如：

```sh
net.core.rmem_max = 134217728
```

## 使用 iperf3 传输大文件

```sh
sudo apt-get install -y iperf3
```

在服务器 A 上：

```sh
iperf3 -s
```

在服务器 X 上：

```sh
iperf3 -c <MACHINE_A_TAILSCALE_IP> -P 8 -t 60
```

- `-P 8`：开 8 条并行 TCP 流，更容易跑满大带宽
- `-t 60`：测 60 秒，测试结果更稳定
- `<MACHINE_A_TAILSCALE_IP>`：服务器 A 在 tailnet 中的 ip，形如 `100.74.x.x`

如果数值接近两台机器中“上行带宽的较小值”，说明 Tailscale 链路 + BBR 调优已经 OK，剩下就是文件传输工具本身的开销了。

## 带宽测试结果

优化前：

```sh
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-60.00  sec  9.71 MBytes  1.36 Mbits/sec  1070     sender
[  5]   0.00-60.01  sec  9.61 MBytes  1.34 Mbits/sec          receiver
[  7]   0.00-60.00  sec  9.54 MBytes  1.33 Mbits/sec  1095     sender
[  7]   0.00-60.01  sec  9.43 MBytes  1.32 Mbits/sec          receiver
...                                                                   
[ 17]   0.00-60.00  sec  7.29 MBytes  1.02 Mbits/sec  1049     sender
[ 17]   0.00-60.01  sec  6.87 MBytes   960 Kbits/sec          receiver
[ 19]   0.00-60.00  sec  6.42 MBytes   898 Kbits/sec  1013     sender
[ 19]   0.00-60.01  sec  6.28 MBytes   878 Kbits/sec          receiver
[SUM]   0.00-60.00  sec  64.4 MBytes  9.00 Mbits/sec  8347     sender
[SUM]   0.00-60.01  sec  63.1 MBytes  8.82 Mbits/sec          receiver
```

优化后：

```sh
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-60.00  sec  11.8 MBytes  1.66 Mbits/sec  2823             sender
[  5]   0.00-60.02  sec  11.0 MBytes  1.54 Mbits/sec                  receiver
[  7]   0.00-60.00  sec  10.8 MBytes  1.51 Mbits/sec  2632             sender
[  7]   0.00-60.02  sec  10.2 MBytes  1.42 Mbits/sec                  receiver
...                                                                   
[ 17]   0.00-60.00  sec  2.77 MBytes   387 Kbits/sec  705             sender
[ 17]   0.00-60.02  sec  2.00 MBytes   279 Kbits/sec                  receiver
[ 19]   0.00-60.00  sec  10.6 MBytes  1.48 Mbits/sec  2503             sender
[ 19]   0.00-60.02  sec  9.78 MBytes  1.37 Mbits/sec                  receiver
[SUM]   0.00-60.00  sec  71.3 MBytes  9.97 Mbits/sec  17491             sender
[SUM]   0.00-60.02  sec  65.6 MBytes  9.17 Mbits/sec                  receiver
```

无明显差异。可能是链路本身的问题，后续再优化。

## 重启 tailscaled + tailscale

```sh
sudo tailscale down && sudo systemctl restart tailscaled && sudo tailscale up
```