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
