# IPMI 访问、设置和常用命令

## 连接 IPMI 接口

不是网卡的口，而是左上方有个单独的 IPMI 的插口。

## 设置路由器 IP

需要根据 IPMI 的静态 IP 地址，修改路由器的 LAN 口 IP。

- 访问路由器：http://tplogin.cn/
- 设备管理 > 设备 > 管理 > 匿名主机 > 找到 IPMI 的 IP 地址
- 路由设置 > LAN 口设置 > LAN 口 IP 设置 > 改为“手动”，并将 IP 地址改为和 IPMI 在同一网段
  - 比如 IPMI 的 IP 是 `192.168.31.101`，则将路由器 LAN 口 IP 改为 `192.168.31.1`
  - 子网掩码 `255.255.255.0`
- 保存并重启路由器即可

## 网页访问 IPMI

在浏览器中直接访问 IPMI 的 IP 地址即可，例如 `http://192.168.31.101`

## 安装 IPMI

```sh
# as root user
apt install ipmitool -y
```

## 调整风扇模式

`Configuration` > `Fan Mode`，设为 `Set Fan to Optimal Speed`

## 设置网络会话超时

`Configuration` > `Web Session` > `Session Timeout Value`，设为 0，表示永不超时。

## 查看传感器信息

```sh
ipmitool sensor list | grep -i fan
ipmitool sensor list | grep -i temp
ipmitool sensor list | grep -i cpu
```

## 查看当前风扇模式

```sh
# Get current Fan mode
ipmitool raw 0x30 0x45 0x00
# 00 → Standard（标准模式）
# 01 → Full（全速）
# 02 → Optimal（节能 / 静音）
# 04 → Heavy I/O（重 I/O / GPU 模式）
```

## 设置风扇为模式

```sh
# Set Fan mode to Full to take full control fans
# 这个会立马开启全转速，需要立刻运行后面的  0x30 0x70 0x66 0x01 <zone> <ratio> 调整转速
ipmitool raw 0x30 0x45 0x01 0x01
```

## 设置告警阈值转速

```sh
ipmitool sensor thresh "FAN1" lower 0 0 0
...
ipmitool sensor thresh "FAN8" lower 0 0 0
```

或者批量设置（推荐）：

```sh
for i in {1..10}; do ipmitool sensor thresh "FAN$i" lower 0 0 0; done
```

这里将最低阈值设为 0，避免风扇转速过低或缺乏风扇触发告警，导致其他风扇拉满产生极大噪声。

注意：每次插拔风扇时，都需要重置告警阈值。不然一旦某个风扇通电后再拔走，就会把 `na` 重新变成 `nr`，就会触发告警，导致其他还在的风扇拉满。

该设置需要重启 IPMI 才能生效。

## 风扇命令注释

```sh
ipmitool raw 0x30 0x70 0x66 0x01 0x00 50
#             |    |    |    |    |    |
#             |    |    |    |    |    └─  占空比百分比（这里是 50%）
#             |    |    |    |    └───── 风扇区域（zone），0x00 通常是 system/CPU 区
#             |    |    |    └────────── 子命令：启用手动模式并设置 PWM
#             |    |    └─────────────── 子命令组 ID（风扇控制）
#             |    └──────────────────── 命令号
#             └───────────────────────── netfn（OEM）
```

```sh
### https://forums.servethehome.com/index.php?threads/supermicro-x9-x10-x11-fan-speed-control.10059/post-446990
# FAN 10 => Zone 0, CPU 1 fan
# FAN 9 => Zone 1, CPU 2 fan
# FAN 6,7,8,9 => Zone 2, Hot swap chassis fans
# FAN 1,2,3,4 => Zone 3, Hot swap chassis fans
#
# ipmitool raw 0x30 0x70 0x66 0x01 0x03 0x02
#                                   ^    ^
#                                  zone fan-speed
#                                  0x00 0x00 = 0 RPM 0%
#                                  0x00 0x64 = 8000 RPM 100%
```

## 手动设置风扇转速


```sh
ipmitool raw 0x30 0x70 0x66 0x01 0x00 40
ipmitool raw 0x30 0x70 0x66 0x01 0x01 40
ipmitool raw 0x30 0x70 0x66 0x01 0x02 40
ipmitool raw 0x30 0x70 0x66 0x01 0x03 40
```

或者批量设置（推荐）：

```sh
for z in 0x00 0x01 0x02 0x03; do ipmitool raw 0x30 0x70 0x66 0x01 $z 40; done
```
