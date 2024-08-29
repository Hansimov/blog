# 使用 ZeroTier 组网

::: tip 快速组网工具Zerotier的使用笔记 - 异地组网_TendCode
* https://tendcode.com/subject/article/Zerotier/#%E5%AE%89%E8%A3%85%E5%AE%A2%E6%88%B7%E7%AB%AF

zerotier/ZeroTierOne: A Smart Ethernet Switch for Earth
* https://github.com/zerotier/ZeroTierOne#getting-started
:::

## 购买具有公网 IP 的服务器

这里以阿里云为例。

选择云服务器 ECS：
- https://www.aliyun.com/product/ecs
  - 选择99元的套餐
  - 选择相应的地域和操作系统

购买完成后查看实例：
- https://ecs.console.aliyun.com/home

点击进入实例详情页：
- `https://ecs.console.aliyun.com/server/<instance-id>/detail`
- 重置密码
- SSH 连接服务器

然后参考：[个人 Ubuntu 配置流程](ubuntu-config)
- 安装配置 zsh、tmux、git 等

## 注册 ZeroTier 账号

- https://my.zerotier.com/

## 创建网络

访问：
- https://my.zerotier.com/network

`Network` - > `Create a Network`
- `Name`
- `Access Control`: `Private`

将会得到一个 `Network ID`，形如 `6a************ff`。后续加入网络需要使用。

## 下载安装 ZeroTier

### Ubuntu 安装

```sh
curl -s https://install.zerotier.com | sudo bash
```

查看服务状态：

```sh
sudo systemctl status zerotier-one
```

重启服务：

```sh
sudo systemctl restart zerotier-one
```

停止服务：

```sh
sudo systemctl stop zerotier-one
```

### Windows 安装

* https://www.zerotier.com/download/#entry-3

安装好后，右下角会出现一个 ZeroTier 的图标。
其中 `My Address` 是当前设备的 ZeroTier 地址，形如 `5e******34`。


## 创建私有根服务器（moon）

::: tip Private Root Servers - ZeroTier Documentation
* https://docs.zerotier.com/roots

简单搭建 Zerotier Moon 为虚拟网络加速 | tvtv.fun
* https://tvtv.fun/vps/001.html

ZeroTier实现内网穿透、异地组网-腾讯云开发者社区-腾讯云
* https://cloud.tencent.com/developer/article/2161650
:::

### Ubuntu 加入网络

```sh
sudo zerotier-cli join 6a************ff
```

列出网络：

```sh
sudo zerotier-cli listnetworks
```

zerotier 的默认工作目录为 `/var/lib/zerotier-one`。

### Windows 加入网络

点击 ZeroTier 图标，选择 `Join New Network`，在 `Network ID` 中输入 `6a************ff`，点击 `Join`。

### 生成私有根服务器的配置文件

运行：

```sh
zerotier-idtool initmoon /var/lib/zerotier-one/identity.public >> moon.json
```

`moon.json` 内容形如：

```json
{
 "id": "74xxxxxx63",
 "objtype": "world",
 "roots": [
  {
   "identity": "74xxxxxx63:0:...", // prefix is world "id", which is also stored in identity.public
   "stableEndpoints": []
  }
 ],
 "signingKey": "****************",
 "signingKey_SECRET": "******************",
 "updatesMustBeSignedBy": "****************", // same to signingKey
 "worldType": "moon"
}
```

在 `stableEndpoints` 中添加云服务器的公网IP和端口（默认为 `9993`）：

```json
"roots": [
  {
    "stableEndpoints": ["***.***.***.***/9993"]
  }
]
```

### 生成签名文件并复制到 moons.d 目录

运行：

```sh
zerotier-idtool genmoon moon.json
```

会创建一个形如 `00000074xxxxxx63.moon` 的文件，打开是乱码。
该文件不包含 `moon.json` 中的私钥，只是由其签名。

这里的 `74xxxxxx63` 与 `moon.json` 中的 `id` 相同，也即 world id。

在 zerotier 根目录下创建 `moons.d` 文件夹，将生成的 .moon 文件复制到 `moons.d` 目录：

```sh
mkdir -p /var/lib/zerotier-one/moons.d
cp ~/*.moon /var/lib/zerotier-one/moons.d
```

### 重启 zerotier 服务以使配置生效

```sh
sudo systemctl restart zerotier-one
```

### 防火墙开启 9993 端口

以阿里云为例，进入面板：
- 云服务器 ECS > 网络与安全 > 安全组
- https://ecs.console.aliyun.com/securityGroup/region/cn-shanghai

选择对应的安全组，管理规则 > 手动添加：
- 授权策略：`允许`
- 优先级：`100`
- 端口范围：`9993`
- 授权对象：`源:所有IPv4(0.0.0.0/0)`
- 描述：`zerotier`

### 查看 planet 的 peers

首先确保新 planet 已经加入了 zerotier 网络。

查看同一网络中的节点信息：

```sh
sudo zerotier-cli peers
```

形如：

```sh{3,4}
200 peers
<ztaddr>   <ver>  <role> <lat> <link>   <lastTX> <lastRX> <path>
6a??????7a 1.14.0 LEAF     248 DIRECT   4668     4451     ???.???.???.???/21008
74??????63 1.14.0 LEAF       5 DIRECT   4668     4662     ???.???.???.???/9993
77??????90 -      PLANET   239 DIRECT   14680    154590   ???.???.???.???/9993
ca??????a9 -      PLANET   260 DIRECT   14680    154569   ???.???.???.???/9993
ca??????a7 -      PLANET   211 DIRECT   14680    149611   ???.???.???.???/9993
ca??????b9 -      PLANET   192 DIRECT   14680    154637   ???.???.???.???/9993
```

可以看到，当前节点（`6a??????7a`）和想要围绕的 moon (`74??????63`) 的 role 目前都是 `LEAF`。

在 ZeroTier 管理界面的 `Members` 信息栏中也可看到节点信息：

- `https://my.zerotier.com/network/6a************ff`

### 让 planet 围绕 moon

```sh
sudo zerotier-cli orbit 74xxxxxx63 74xxxxxx63
```

这里的两个 `74xxxxxx63` 相同：
- 第一个表示 moon 的 world id
- 第二个表示该 moon 的任何根服务器的地址，这可以使其联系根服务器以获得整个 world 的信息

再次查看同一网络中的节点信息：

```sh
sudo zero-tier-cli peers
```

形如：

```sh{3}
<ztaddr>   <ver>  <role> <lat> <link>   <lastTX> <lastRX> <path>
6a??????7a 1.14.0 LEAF     248 DIRECT   4782     4564     ???.???.???.???/21008
74??????63 1.14.0 MOON      -1 RELAY
77??????90 -      PLANET   240 DIRECT   24806    89635    ???.???.???.???/9993
ca??????a9 -      PLANET   260 DIRECT   24806    89614    ???.???.???.???/9993
ca??????a7 -      PLANET   211 DIRECT   24806    84658    ???.???.???.???/9993
ca??????b9 -      PLANET   192 DIRECT   4782     34438    ???.???.???.???/9993
```

可以看到这里 `74??????63` 的 role 已经变为 `MOON`。

`DIRECT` 表示直连，`RELAY` 表示通过中继服务器连接。

如果要离开 moon，可以运行：

```sh
sudo zerotier-cli deorbit 74xxxxxx63
```

## 授权 Nodes

默认加入网络的 Nodes 是未授权的，此时彼此之间还不能通过局域网 IP 直接通信。

访问：
- https://my.zerotier.com/network
- 找到对应网络，点击 `Members`
- 全选节点，点击 `Authorize`

这时即可看到每个节点分配的 `Managed IP`，形如：

```sh{2,3,4}
Auth  Address     Name/Desc  Managed IPs      Last Seen  Version  Physical IP
√     49??????8b             192.168.19?.???  1 minute   1.14.0   ???.???.???.??? 
√     5e??????34             192.168.19?.???  1 minute   1.14.0   ???.???.???.??? 
√     74??????63             192.168.19?.???  1 minute   1.14.0   ???.???.???.???
```

此时，在网络中任一 planet 上查看 peers：

```sh
sudo zerotier-cli peers
```

则会显示出全部加入的节点，且 `<path>` 已经被更新为 `Managed IP`：

```sh{3,4,5}
200 peers
<ztaddr>   <ver>  <role> <lat> <link>   <lastTX> <lastRX> <path>
5e??????34 1.14.0 LEAF       3 DIRECT   18928    18926    192.168.???.???/24937
6a??????7a 1.14.0 LEAF     213 DIRECT   11333    18778    ???.???.???.???/21008
74??????63 1.14.0 MOON      -1 RELAY
77??????90 -      PLANET   237 DIRECT   11333    86100    ???.???.???.???/9993
ca??????a9 -      PLANET   263 DIRECT   11333    86076    ???.???.???.???/9993
ca??????a7 -      PLANET    65 DIRECT   1332     1268     ???.???.???.???/9993
ca??????b9 -      PLANET   195 DIRECT   11333    86142    ???.???.???.???/9993
```

此时，planet 之间即可互相通过 `Managed IP` 进行通信。
可以用 ping 测试连接和延迟。

## 命令行参数

### zerotier-cli

```
zerotier-cli --help
```

```sh
ZeroTier One version 1.14.0 build 0 (platform 1 arch 2)
Copyright (c) 2020 ZeroTier, Inc.
Licensed under the ZeroTier BSL 1.1 (see LICENSE.txt)
Usage: zerotier-cli [-switches] <command/path> [<args>]

Available switches:
  -h                      - Display this help
  -v                      - Show version
  -j                      - Display full raw JSON output
  -D<path>                - ZeroTier home path for parameter auto-detect
  -p<port>                - HTTP port (default: auto)
  -T<token>               - Authentication token (default: auto)

Available commands:
  info                    - Display status info
  listpeers               - List all peers
  peers                   - List all peers (prettier)
  listnetworks            - List all networks
  join <network ID>          - Join a network
  leave <network ID>         - Leave a network
  set <network ID> <setting> - Set a network setting
  get <network ID> <setting> - Get a network setting
  listmoons               - List moons (federated root sets)
  orbit <world ID> <seed> - Join a moon via any member root
  deorbit <world ID>      - Leave a moon
  dump                    - Debug settings dump for support

Available settings:
  Settings to use with [get/set] may include property names from
  the JSON output of "zerotier-cli -j listnetworks". Additionally,
  (ip, ip4, ip6, ip6plane, and ip6prefix can be used). For instance:
  zerotier-cli get <network ID> ip6plane will return the 6PLANE address
  assigned to this node.
```

### zerotier-idtool

```
zerotier-idtool orbit --help
```

```sh
ZeroTier One version 1.14.0
Copyright (c) 2020 ZeroTier, Inc.
Licensed under the ZeroTier BSL 1.1 (see LICENSE.txt)
Usage: zerotier-idtool <command> [<args>]

Commands:
  generate [<identity.secret>] [<identity.public>] [<vanity>]
  validate <identity.secret/public>
  getpublic <identity.secret>
  sign <identity.secret> <file>
  verify <identity.secret/public> <file> <signature>
  initmoon <identity.public of first seed>
  genmoon <moon json>
```
