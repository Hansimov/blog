# 使用 Tailscale 组网

遇到高延迟或网站加载缓慢，先看下文的
[旧 IPv6 前缀残留导致中继回退](#旧-ipv6-前缀残留导致中继回退)，
不要先重启整张网卡、关闭防火墙或盲目调大 TCP 缓冲区。

## 注册账号

注册：https://tailscale.com

## Windows 安装 Tailscale

下载：https://tailscale.com/download/windows

被远程访问的 Windows 设备需要打开 `远程桌面设置`，将 `启用远程桌面` 打开。

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

## 查看 tailscale 网卡的 ipv6 地址

查看是否都是 `disable_ipv6=0`：

```sh
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6
sysctl net.ipv6.conf.tailscale0.disable_ipv6
```

查看 tailscale0 网卡信息：

```sh
ip link show tailscale0
```

查看 tailscale 的 ipv6 地址：

```sh
tailscale ip -6
```

输出形如：

```sh
fd7a:****:****::****:****
```

```sh
ip -6 route show table 52 | sed -n '1,80p'
```

输出形如：

```sh
fd7a:****:****:53 dev tailscale0 metric 1024 pref medium
fd7a:****:****::/48 dev tailscale0 metric 1024 pref medium
```

如果没有输出，可以重启服务：

```sh
sudo systemctl restart tailscaled && sudo tailscale up
```

一般都可以的。


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

### 安装 speedtest

```sh
sudo snap install speedtest
```

测试带宽上限：

```sh
speedtest
```

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

远程执行会中断 Tailscale 管理连接，必须先准备 PVE 控制台或其他独立管理通道。
重启 Tailscale 不会清除 NetworkManager 保存的旧 IPv6 自动配置状态。

```sh
sudo tailscale down && sudo systemctl restart tailscaled && sudo tailscale up
```

## 旧 IPv6 前缀残留导致中继回退

### 2026-10 的现象与根因

desktop 访问 ai122 一度绕行旧金山 DERP，中继延迟约 300–900 ms，并伴有超时。
两端 UDP 检测都通过，但 ai122 的默认 IPv6 源地址不可用。它同时保留两组公网前缀：
旧前缀的绑定源地址探测失败，新前缀的探测成功；当时默认路由器的 RA 只通告新前缀。
不能把“本机有全局 IPv6 地址”当作“IPv6 公网正常”。

第一次把旧地址的 `preferred_lft` 设为零后，直连立即恢复，普通 ping 三十次零丢包，
平均约 45 ms。但这只是运行时缓解：数分钟后旧地址重新变为 preferred，还生成了
旧前缀下的新临时地址，连接再次回退到 DERP。**短时间测试通过不等于修复完成。**

进一步处理是通过 NetworkManager **仅刷新所选接口的 IPv6 自动配置状态**，
重新学习当前路由通告；不执行 `connection down/up`，不重启 NetworkManager，
不改 IPv4、默认防火墙或代理。刷新后旧前缀地址消失，IPv4 地址保持不变，
Tailscale 恢复 IPv6 直连。这与前缀变更后旧状态未及时撤销的情况一致；
不能仅凭一次 RA 捕获断言路由器完整的历史行为。

后续检查还需要覆盖新的 RA、临时地址更新和一段持续访问，而非只测一次 ping。
路由器如何撤销旧前缀可参考 [RFC 9096](https://www.rfc-editor.org/rfc/rfc9096.html#name-signaling-stale-configuration)。
客户端防护不能替代路由器正确处理前缀变更，也不能保证运营商链路没有抖动。

### 先确认路径，再测延迟和吞吐

在 desktop 上运行：

```powershell
# 是否直连、实际使用 IPv4/IPv6，还是 via DERP(...)
tailscale ping --c 20 --until-direct=false --timeout 2s ai122

# 普通 ICMP，验证经过系统网络栈后的结果
ping -n 30 ai122
```

独立、限时、只允许测试客户端访问的内存数据测试中，两次 8 MiB 下载约 1.08/1.34 秒，
即约 62/50 Mbps；临时测试监听随后关闭，没有对外暴露目录。小文件测量包含握手和
首包等待，不能直接当作带宽上限；短传输也不是持续吞吐保证。
后续一分钟抽样中，路径十二次检查均保持 IPv6 直连，普通 ping 平均约 43 ms，
但六十包中仍有两包超时：恢复直连不等于公网链路完全无丢包。

在 VM 中对照检查：

```sh
tailscale ping --c 20 --until-direct=false --timeout 2s DESKTOP_HOSTNAME
tailscale netcheck
```

这里 `DESKTOP_HOSTNAME` 要换为 Tailscale 中实际的机器名，不是假设一定叫 `desktop`。
直接运行原生 Tailscale、`ip address`、`ss`、`journalctl` 可能输出真实地址和用户信息，
请只在私有终端检查。正式排查方法参见
[Tailscale 性能故障排查](https://tailscale.com/docs/reference/troubleshooting/poor-performance-tailnet)。

### 安全诊断与 NetworkManager 修复脚本

仓库脚本：[tailscale_ipv6_repair.py](./scripts/pve-vm/tailscale_ipv6_repair.py)。
在 VM 上安装；接口名必须用当前物理网卡，不能照搬历史 GPU 拓扑下的旧接口名。

```sh
sudo install -m 755 tailscale_ipv6_repair.py /usr/local/sbin/tailscale-ipv6-repair

# 默认只诊断，不更改地址、路由或服务
sudo tailscale-ipv6-repair --interface enp7s18

# P1 是上一步输出的标签，不是固定前缀；修复会重新检查所有证据
sudo tailscale-ipv6-repair repair --interface enp7s18 --stale-prefix P1
```

依赖 Linux、Python 3.9+、iproute2、NetworkManager、systemd 和支持
`netcheck --format=json --bind-address` 的 Tailscale。已在 Tailscale 1.102.2、
NetworkManager 1.36.6 环境验证。需要 root 接收原始 IPv6 路由通告。

修复前必须同时满足：

- 所选接口只有一条 IPv6 默认路由；当前默认源属于待修复前缀。
- 两次绑定源地址的 IPv6 检测均失败，而至少一个替代前缀的两次检测均成功。
- 当前默认路由器的有效 RA 通告替代前缀，不通告待修复前缀；修复前再次确认 RA 和地址快照。
- 地址属于动态 SLAAC `/64`，NetworkManager 配置为 `ipv6.method=auto`，并存在 IPv4 管理路径。

多路由、静态地址、RA 缺失、检查工具出错或证据变化时拒绝自动修复。
脚本不只凭 ping 失败来判断旧地址，也不会固定写死某个公网前缀。

修复过程短暂将该设备的运行时 `ipv6.method` 从 `auto` 切为 `disabled` 再恢复 `auto`。
**IPv6 连接可能短暂中断**，因此应经 PVE guest agent/控制台或独立 IPv4 通道执行。
`finally` 恢复之外，还有独立的 90 秒恢复定时器，防止调用方断开或进程被杀后长期停用 IPv6。
脚本验证 IPv4 地址/默认路由未变化、新前缀可用且旧前缀已消失，成功后取消恢复定时器。
没有修改磁盘中的 NetworkManager 连接配置；这是清理缓存，不是静态地址绑定。

备份位于 `/var/backups/tailscale-network/`，目录 `0700`、文件 `0600`，包含真实地址、
连接名称、machine/boot ID，**只能留在私有主机，不可提交**。必要时：

```sh
sudo tailscale-ipv6-repair restore --interface enp7s18 \
  --backup /var/backups/tailscale-network/ipv6-TIMESTAMP.json
```

恢复仅适用于本脚本创建的同机、同接口、同次启动备份，作用是重新启用 IPv6 自动配置，
**不会重建已经失效的旧地址**，也不承诺还原旧 SLAAC 缓存。

### 持久防复发：按接口启用检查定时器

先手动诊断并确认适用，再安装仓库内的两个模板：

```sh
sudo install -m 644 tailscale-ipv6-guard@.service tailscale-ipv6-guard@.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-ipv6-guard@enp7s18.timer

# 手动执行一轮并查看结果
sudo systemctl start tailscale-ipv6-guard@enp7s18.service
sudo journalctl -u tailscale-ipv6-guard@enp7s18.service -n 20 --no-pager
sudo systemctl list-timers 'tailscale-ipv6-guard@*'
```

定时器开机后启动，每轮结束约两分钟后再检查，附加最多十秒随机延迟。
默认源仍在当前 RA 中时直接退出，不重启网络，也不反复测速。
只有发现疑似旧前缀才运行完整证据检查；符合上述条件才刷新 IPv6。
因此它不是“每两分钟重启网络”，也不是故障出现瞬间就能恢复的保证。
不使用 NetworkManager 或多默认路由的主机不要直接启用，应人工诊断。

停用自动维护不会撤销已经恢复的健康地址：

```sh
sudo systemctl disable --now tailscale-ipv6-guard@enp7s18.timer
```

公开脚本的正常输出使用 `P1/P2` 标签和计数，不打印真实 IP、路由器标识或原始 netcheck
日志；异常也不打印可能含地址的命令参数/堆栈。模板不含主机凭据或公网地址。

### 离线回归测试

在 Linux 上运行以下命令；私有备份权限测试需要 root。测试中的网络、systemd、
NetworkManager 修改均被 mock，不会真实改变服务或地址，示例地址只使用文档保留网段。

```sh
sudo python3 -B -m unittest discover -s docs/notes/scripts/pve-vm/tests -v
```

覆盖旧前缀证据不足时拒绝修改、RA/源地址中途变化、健康状态不操作、IPv4 变化检测、
恢复定时器启动失败、更新中断后恢复 `auto`、备份权限、脱敏输出和 V2Ray 诊断不修改生产配置。

## IPv6 直连仍慢：检查 Tailscale 实际 UDP 源端口

### 2026-10 的另一次复发

这次不是旧 IPv6 前缀重新出现：ai122 只有当前有效前缀，IPv6 guard 定时器正常，
desktop 与 ai122 已经是 IPv6 直连，但延迟约 113–119 ms，并有探测超时；
两次独立的 8 MiB 内存数据下载约 4 秒，约 17 Mbps。两端接口当时没有带宽占满的迹象。
因此，不能看到“直连”就认为链路质量正常，也不能把所有复发都归因于同一个问题。

新的关键证据是 **守护进程的端口与独立 `netcheck` 的端口表现不同**：

- `tailscaled` 使用 UDP 41641；在 VM 外网接口抓取 STUN 流量，观察到该端口发出 90 个 IPv4 探测，
  没有收到 IPv4 回包；同期 IPv6 探测有回包。守护进程也没有公布公网 IPv4 端点。
- 普通 `tailscale netcheck` 使用另一个临时源端口，可以发现公网 IPv4；固定到两个空闲端口也成功。
- 执行 `tailscale debug restun`、`tailscale debug rebind` 均没有恢复原端口的 IPv4 探测。
- 换端口后，再用独立探测交替测试已释放的旧端口与另一个空闲端口：旧端口两次均失败，替代端口成功。
  这比单纯“重启后变快”更能说明差异与源端口有关。
- 旧端口闲置数分钟后再次探测也恢复成功，更符合暂态 NAT/连接跟踪状态问题，不能说成永久端口封锁。

路由器 UPnP 报告的 WAN 地址不是公网地址，而 STUN 能观察到公网地址，说明还有上游 NAT。
VM 网卡没有启用 PVE 的逐网卡防火墙，检查中未发现针对旧端口的 PVE 丢弃规则。
证据指向原 UDP 源端口对应的外部网络/NAT 路径异常；**尚不能确定是某级路由器映射失效、
映射冲突还是运营商过滤**。没有为验证猜测而删除路由器映射、关闭防火墙或全局禁用 IPv6。

### 先探测空闲端口，不要盲目换端口

隐私安全的诊断脚本：[tailscale_udp_probe.py](./scripts/pve-vm/tailscale_udp_probe.py)。
需要支持 `netcheck --bind-port --format=json` 的 Tailscale；本次使用 1.102.2。

```sh
# 只发送诊断探测，不更改服务、路由或防火墙；端口须按实际占用情况选择
python3 tailscale_udp_probe.py --ports 0 41642 41643 --repeats 2
```

脚本交替探测不同 IPv4 UDP 源端口，只输出端口、轮次及成功/失败状态，不打印地址、原始日志或凭据。
`stun_ok` 要求收到 UDP 回包且报告有效的公网 IPv4 端点；单看 `IPv4=true` 不够，
本次旧端口在 UDP 不通时仍出现该标记。`port_unavailable` 表示端口无法绑定，**不是网络不通**。
正在被 `tailscaled` 使用的端口必须跳过，不能为了诊断先停服务；应使用守护进程指标与限时抓包观察它。
固定源端口的成功也不保证所有 peer 都能打洞，最终仍要验证实际 peer 的路径和吞吐。

原生指标可在私有终端查看：

```sh
tailscale debug metrics | grep -E '^netcheck_stun_(send|recv)_ipv[46] '
```

这些计数是守护进程启动以来的累计值，需要在一次探测前后取差值。
完整 `netmap`、`netcheck`、抓包和服务日志可能含真实地址或节点标识，不要提交到公开仓库。

### 有独立管理通道和自动回退后，再持久化

本次确认 `/lib/systemd/system/tailscaled.service` 从 `/etc/default/tailscaled` 读取 `PORT`，
然后持久化为已经探测可用的 UDP 41642，仅重启 `tailscaled`，没有运行 `tailscale down/up`，
没有重启 VM、修改代理服务或刷新正常的 IPv6 配置。
Tailscale 的 `ts-input` 规则自动跟随新监听端口；没有扩大其他服务的防火墙开放范围。

端口不是通用“最优值”。操作其他主机前，应先检查其实际 systemd 单元、端口占用及已有端口转发规则。
官方说明见 [Tailscale UDP 端口配置](https://tailscale.com/docs/reference/faq/firewall-ports)
和 [tailscaled 参数](https://tailscale.com/docs/reference/tailscaled)。

执行时必须通过 PVE guest agent、控制台或其他独立管理通道，并按以下顺序操作：

1. 备份原文件到 root 专用目录，记录权限；先验证替代端口能够完成 IPv4 STUN。
2. 启动独立于当前 SSH 会话的限时回退任务（本次为 systemd 120 秒定时器），
   到期自动恢复原配置并重启 `tailscaled`。
3. 仅修改 `PORT` 并重启 `tailscaled`；检查服务状态、实际 UDP 监听端口及 peer 直连是否恢复。
4. 在回退期限内确认有效后取消回退，再持续测量延迟、丢包和限量吞吐。
   如果失败，保留回退任务或通过独立通道立即恢复，不能依赖已经中断的 Tailscale 会话。

示意回退命令如下；`BACKUP_FILE` 必须换成已核对的私有备份文件：

```sh
# 仅用于本例原文件属于 root、权限为 0644 的 Debian/Ubuntu 安装
sudo install -o root -g root -m 0644 BACKUP_FILE /etc/default/tailscaled
sudo systemctl restart tailscaled
```

本次切换后自动选择 IPv4 直连，首轮延迟约 25–29 ms，两次 8 MiB 下载约 0.91/1.25 秒，
约 73/54 Mbps。随后约六分钟、十二轮路径检查始终为 IPv4 直连，六次下载约 34–74 Mbps；
没有把最好的单次结果当成稳定带宽。小文件结果包含建连开销，不代表持续带宽上限。

**主要性能瓶颈恢复不等于全部丢包消失。** 后续一轮普通 ICMP 为 81/90 成功，成功包平均约 29 ms，
而本地网关 90/90 成功。进一步使用带专用标记的测试负载避免混入其他 ping：
desktop 发出 30 个请求，VM 的 `tailscale0` 观察到 28 个并全部回复，desktop 也收到这 28 个回复。
另一次 Windows 分层 UDP 包计数未见本地 NDIS/WFP 组件丢弃，但 35 次 ping 仍有 2 次超时；
PVE 物理网卡与该 VM 的 tap 接口采样中没有错误或丢弃增量。
这些证据把残余问题缩小到请求到达 VM 隧道接口之前的路径，尚不足以指认某一台上游设备。
没有把累计的网桥/网卡丢弃数直接当作本次测试丢包，也没有用增大缓冲区来掩盖未定位的原因。

不能保证更换端口永久消除上游 NAT 或运营商问题，因此未添加“慢了就定时重启/轮换端口”的任务。
原来的 IPv6 前缀 guard 保留，它处理另一类故障，与本次 UDP 端口修复互不替代。

### 本机有线网卡的带宽上限与可回退测试

本次还发现 desktop 的 Intel 网卡被固定为 `100 Mbps Full Duplex`，实际链路也是百兆。
Intel 对 I219 系列的千兆连通性排查建议检查对端能力、线路及自动协商，见
[I219-V 千兆速率排查](https://www.intel.com/content/www/us/en/support/articles/000058667/ethernet-products/gigabit-ethernet-controllers-up-to-2-5gbe.html)。
这不代表只改一个驱动选项就能得到千兆，也不能据此断定它造成了所有公网丢包。

通过管理员 PowerShell 只读检查：

```powershell
Get-NetAdapter | Select-Object Name, Status, LinkSpeed
Get-NetAdapterAdvancedProperty -Name 'ADAPTER_NAME' -RegistryKeyword '*SpeedDuplex'
```

现场在独立的 120 秒计划任务回退保护下测试了自动协商：网卡短暂断链后恢复，但仍然只有 100 Mbps，
后续网关连通性验证出现超时，因此没有保留这个试验；恢复原来的固定百兆全双工配置后，
网关复测 5/5 成功，回退计划任务已移除。跨越断链和回退时间段的 ping 不能用于评价稳定态丢包率。
这次并未证明是网线故障或对端双工不匹配；继续处理需要检查物理线路和对端端口的速率、双工及错误计数。
不要强制千兆、关闭驱动过滤器或把所有卸载功能一并禁用来碰运气。

### 残余丢包：四个抓包点定位与单变量对照

继续排查时，IPv4 直连延迟已经恢复到约 25–30 ms，但仍间歇丢包。
为了避免仅凭 ping 推断原因，对同一条 Tailscale UDP 流同时观察四个位置：

```text
desktop 网卡抓包点 → PVE 物理网卡 → VM 对应的 tap 接口 → VM 网卡
```

Windows 使用已有的 Npcap，Linux 使用限时 tcpdump。以加密 UDP 负载的指纹匹配同一个包，
不把经过 NAT 后会变化的外层 IP、端口或校验和加入指纹；裁掉抓包窗口两端，避免启动/停止时差。
原始记录仅存于内存或私有目录，分析后删除，没有提交抓包、端点地址或节点密钥。
Windows 分层包计数还可使用 [Pktmon](https://learn.microsoft.com/en-us/windows-server/networking/technologies/pktmon/pktmon)，
但必须先确认它实际记录了包；空抓包文件不能证明链路没有流量或没有丢包。

这个过程中发现两个会误导计数的因素：

- 多台 Tailscale 节点可能共用公网地址，过滤条件必须包含当前 peer 的 UDP 端口，不能只匹配公网 IP。
- VM 的 GRO 会把多个 UDP 数据报合并为一条抓包记录，最后一段还可能较短。
  现场出现过 `96 + 80` 字节的 WireGuard 负载聚合；不能只接受长度为 96 的记录，
  也不能要求总长度一定是 96 的整数倍。初步看到的少量“PVE 有、VM 无”因此不是真实丢包证据。

校正过滤条件及聚合解析后，最后一轮有效窗口中的结果为：

| 方向 | 发送端观察到的小型加密包 | 接收端匹配到 | 缺失位置 |
| --- | ---: | ---: | --- |
| desktop → VM | 60 | 56 | 4 个均在 PVE 物理网卡处就未出现 |
| VM → desktop | 39 | 39 | 无缺失 |

同一窗口中，PVE 物理网卡、tap 和 VM 之间没有匹配包缺失；Linux 抓包报告没有内核抓包丢弃。
这是经过筛选和裁剪窗口的报文统计，不等同于整轮 ping 的样本量，也不能据此推导全天丢包率。
网卡抓包点还不等于物理线上已经成功发送，因此仍需考虑本机网卡硬件、网线、交换机、
两端路由器和运营商路径，**不能直接断定是运营商，也不能把责任归给 PVE 虚拟网桥**。

另外做了三项可回退、单变量对照，都没有保留为长期配置：

| 试验 | 观测 | 最终处理 |
| --- | --- | --- |
| desktop 的 Tailscale UDP 端口改为另一个已通过 STUN 的空闲端口 | 普通 ping 46/50，Tailscale 探测 18/20，未见稳定改善 | 删除本次新增的端口覆盖文件，恢复默认监听端口 |
| 仅临时阻断目标 peer 的 IPv4 UDP 端点，对照 IPv6 直连 | 探测 15/20，延迟约 56 ms，下载约 25–35 Mbps，比 IPv4 更差 | 删除精确到 peer 端点的测试规则，恢复自动选路 |
| 仅关闭本机 IPv4 UDP 的发送校验和卸载，保留接收卸载及其他设置 | 普通 ping 53/60，仍有丢包；上述最终四点比对也在此阶段完成 | 恢复原来的收发卸载状态 |

端口设置遵循 [Tailscale 的 Windows 配置说明](https://tailscale.com/docs/reference/tailscaled#environment-variables)；
校验和对照使用 [Set-NetAdapterChecksumOffload](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterchecksumoffload)，
仅改变 `UdpIPv4Enabled`，没有一起关闭 TCP、IPv6 卸载或卸载驱动。各项试验都预先设置独立回退任务，
确认恢复后移除任务；网卡重连和服务启动阶段的数据不作为稳定态效果的证据。

最终保留 ai122 已验证有效的 UDP 端口修复和 IPv6 前缀 guard；desktop 恢复原端口、百兆全双工及原卸载设置，
没有残留试验防火墙规则或定时重启任务。**剩余丢包尚未消除。** 下一步应在得到网络设备管理权限后，
检查两端接入设备的接口错误、丢弃、双工、NAT/连接跟踪和 QoS 计数，并做网线/端口或备用接入线路对照，
而不是继续随机修改 VM 的 MTU、缓冲区或防火墙。

全部试验回退后的最后复测保持 IPv4 直连：30 次 Tailscale 探测成功 29 次，中位延迟约 27 ms，
两次 8 MiB 下载约 60/67 Mbps。短窗口间丢包率会波动，这个结果不能当作新的优化已经消除丢包的证明。
