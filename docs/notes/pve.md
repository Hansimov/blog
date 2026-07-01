# 安装 PVE

## 使用 Rufus 制作 PVE 启动盘

::: tip ISO - Proxmox Virtual Environment
- https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso
- https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso

Rufus - 轻松创建 USB 启动盘
- https://rufus.ie/zh/#download
- https://github.com/pbatard/rufus/releases/download/v4.11/rufus-4.11.exe
:::


## 4029GP BIOS/BMC 设置

### 进入 BIOS
- `IPMI` > `Remote Control` > `Launch Console`
- 开机自检时,虚拟键盘，狂按 Delete 进入 UEFI BIOS（Supermicro X11 系列主板默认是 Del）
- 如果一直没看到 BIOS 的显示，可以在第一步再新开一个控制台窗口

### 开启虚拟化相关

- `Advanced` > `CPU Configuration`
  - `Intel Virtualization Technology (VT-x)` 设为 `Enable`

- `Advanced` > `Chipset Configuration`
  - `North Bridge` > `IIO Configuration` > `Intel@ VT for Directed I/O (VT-d)`
  - 全都设为 `Enable`

- `Advanced` > `PCIe/PCI/PnP Configuration`
  - `SR-IOV Support` 设为 `Enabled`
  - `Above 4G Decoding` 设为 `Enabled`

### UEFI & Secure Boot
- `Boot` > `Boot Mode select` 设为 `UEFI`
- `Security` > `Secure Boot` 设为 `Disabled`

### RAID/存储控制器

- `Advanced` > `PCIe/PCI/PnP Configuration`
  - `SYS-4029GP-TRT PCIE Option Rom Setting`
  - `CPU` 和 `PCH` 开头的所有 `PCIE x16 OPROM` 都设为 `EFI`

在 BIOS 的 `Advanced` -> PCIe/PCI/PnP 之类菜单里找到 S3108 的 Option ROM，设为 UEFI 模式，否则有可能装完系统后出现找不到 GRUB 的问题。

### 设置启动顺序
- `Boot` > `FIXED BOOT ORDER Priorities`
  - 选中 U 盘所在的 Boot Option，按 `+` 提升到第一位
  - 或者回车选中 Boot Option 1，将其设为 U 盘
  - 类似 `UEFI USB Key: UEFI: VendorCoProductCode 2.00, Partition 2`
- 安装完成之后再将 Intel 1TB SSD 改为第一位
  - 类似 `UEFI Hard Disk: Ubuntu (INTEL SSDPF2KX960HZ-****)`

### 保存并退出 BIOS 设置
- `Save & Exit` > `Save Changes`
- 按 `F4` 保存并退出 BIOS 设置

这样应该就会从 U 盘启动。

## GA-X99-UD4 BIOS 设置

::: tip GIGABYTE GA-X99-UD4 User's Manual Rev. 1103:
- https://download1.gigabyte.com/Files/Manual/mb_manual_ga-x99-ud4_v1.1_e.pdf

Proxmox VE PCI Passthrough:
- https://pve.proxmox.com/wiki/PCI_Passthrough

Proxmox VE Secure Boot Setup:
- https://pve.proxmox.com/wiki/Secure_Boot_Setup

Intel Virtualization Technology:
- https://www.intel.com/content/www/us/en/support/articles/000005486/processors.html
:::

### 进入 BIOS

- GA-X99-UD4 是普通桌面/工作站主板，没有 4029GP 那种 BMC/IPMI KVM，需要接显示器和键盘操作
- 开机自检时按 `Delete` 进入 BIOS Setup
- 临时从 U 盘启动可以按 `F12` 打开 Boot Menu
  - 这个选择只对本次启动生效，不会改 BIOS 里的永久启动顺序
- 如果刚刷过 BIOS 或清过 CMOS：
  - `Save & Exit` > `Load Optimized Defaults`
  - 载入默认值后再按下面的小节逐项调整

### 开启虚拟化相关

- `Chipset`
  - `Intel VT for Directed I/O (VT-d)` 设为 `Enabled`
  - 官方手册里这个选项默认就是 `Enabled`，但装 PVE 前建议确认一遍

- 如果当前 BIOS 版本里能看到下面这些名字，也设为 `Enabled`：
  - `Intel Virtualization Technology`
  - `VT-x`
  - `Intel VMX`

官方 GA-X99-UD4 手册只明确列出了 `VT-d`，没有单独列出 `VT-x` 开关。Intel 文档里说明 VT-x 需要 CPU 和 BIOS 同时支持；如果 BIOS 里找不到独立 VT-x 选项，先确认 CPU 型号本身支持 VT-x，然后安装 PVE 后用命令验证：

```sh
grep -m1 -o vmx /proc/cpuinfo
dmesg | grep -e DMAR -e IOMMU
```

如果第二条能看到类似 `DMAR: IOMMU enabled`，说明 IOMMU/VT-d 已经被系统识别。

### UEFI & CSM

- `BIOS Features`
  - `Fast Boot` 设为 `Disabled`
  - `Boot Option Priorities` 里选择带 `UEFI:` 前缀的 U 盘启动项
  - 如果看不到 `CSM Support`：
    - 先把 `Windows 8 Features` 设为 `Windows 8`
    - 再回到 `CSM Support`
  - `CSM Support` 建议设为 `Disabled`

如果某块老显卡、老 RAID 卡或老 HBA 不支持 UEFI，导致关掉 CSM 后黑屏或看不到启动盘，可以先保留 `CSM Support` 为 `Enabled`，但仍然把下面两个 Option ROM 设为 UEFI：

- `BIOS Features`
  - `Storage Boot Option Control` 设为 `UEFI`
  - `Other PCI Device ROM Priority` 设为 `UEFI`

### Secure Boot

GA-X99-UD4 Rev. 1103 手册里没有单独列出 `Secure Boot` 菜单。如果当前 BIOS 版本能看到这个选项：

- 装 PVE 时建议先设为 `Disabled`
- 如果后续确实需要 Secure Boot，再按 Proxmox 官方 Secure Boot 文档切回启用

### SATA/存储控制器

- `Chipset` > `PCH SATA Configuration`
  - `SATA Controller` 设为 `Enabled`
  - `Configure SATA as` 设为 `AHCI`

- `Chipset` > `PCH sSATA Configuration`
  - `sSATA Controller` 设为 `Enabled`
  - `Configure sSATA as` 设为 `AHCI`

PVE 直装到 SATA SSD/HDD 时建议用 AHCI。除非你明确要用主板 Intel RAID，否则不要设为 `RAID`，否则后面磁盘识别和维护会更麻烦。

### USB 启动兼容性

- `Peripherals`
  - `Legacy USB Support` 保持 `Enabled`
  - `XHCI Hand-off` 保持 `Enabled`

- `Chipset`
  - `XHCI Mode` 保持默认的 `Smart Auto` 即可

这样可以降低 USB 键盘和 USB 3.0 启动盘在安装器里失灵的概率。

### PCIe 相关

- `M.I.T` > `Miscellaneous Settings`
  - `PCIe Slot Configuration` 保持 `Auto`

官方手册没有列出 `Above 4G Decoding` 或 `SR-IOV Support`。如果你刷到的 BIOS 版本里能看到：

- `Above 4G Decoding`：做 GPU/大 BAR PCIe 设备直通时建议设为 `Enabled`
- `SR-IOV Support`：只有需要网卡等设备 SR-IOV 时才设为 `Enabled`

如果 BIOS 里没有这些项，就不要按 4029GP 的菜单硬找；先按 `VT-d` + UEFI 启动把 PVE 装起来。

### 设置启动顺序

- 临时启动：
  - 开机按 `F12`
  - 选择类似 `UEFI: <你的U盘型号>` 的启动项

- 固定启动：
  - `BIOS Features` > `Boot Option Priorities`
  - `Boot Option #1` 选带 `UEFI:` 前缀的 PVE 安装 U 盘
  - 安装完成后，把 `proxmox` 或安装目标硬盘的 UEFI 启动项改为第一位

### 保存并退出 BIOS 设置

- `Save & Exit` > `Save & Exit Setup`
- 选择 `Yes` 保存到 CMOS 并重启

这样应该就会从 U 盘以 UEFI 模式启动 PVE 安装器。

## 从 U 盘安装 PVE

### 从 U 盘启动

- 插好 U 盘；
- 开机时按 F11/F12（取决于 BIOS），选 USB 启动
- 如果上面 BIOS 设置了 U 盘为第一启动项，则默认进入 PVE 启动画面。
- 在 PVE 启动画面里选：`Install Proxmox VE (Graphical)`
- 许可协议：EULA 直接 `Accept`。

### 选择安装目标硬盘

- `Target Harddisk`
  - 单盘部署：选择 Zhitai 1TB SSD
  - 双盘部署：选择 1TB Intel SSD（通过容量和型号区分），确认不要选错成 4TB
- 点击右边的 `Options`：
  - `Filesystem`：选 `ext4`（默认），PVE 会在这块盘上创建 LVM + LVM-Thin，root 用 ext4
  - 其他参数（hdsize, swapsize, maxroot, minfree, maxvz）可以先用默认值
  - 如果只有这一块 1TB SSD，后面直接使用默认的 `local-lvm` 运行 VM
  - 如果另有 4TB SSD，后面再把 4TB 盘加成新的 VM 存储

### 地区 & 键盘布局
  - Country 选 China
  - Time zone：选 Asia/Shanghai
  - Keyboard：选 U.S. English

### root 密码和邮箱
- 设置密码，用户名固定是 `root` （浏览器登录时用到）
- Email 用来收报警/备份通知，将来想用 Proxmox Backup 或 ACME 证书很有用。

### 网络配置
- 选一块你打算用作管理口的网卡
  - 一般是第一块 10GBase-T 口
  - 名称类似 `nic0` (`enolnp0`)
  - 可以点进 `Pin network interface names` 右边的 `Options`，查看网卡名称
- Hostname：例如 `pve.83080.4029gp`
- IP 配置建议用静态 IP：
  - IP：例如 `192.168.31.103`
  - Gateway：例如 `192.168.31.1`
  - DNS Server：例如 `192.168.31.1`

### 开始安装
- 再检查一眼目标硬盘是不是计划安装 PVE 的那块 SSD；
- 点 Install，几分钟就装完（这时代码会装完整 Debian + PVE 包）。

### 首次重启
- 默认会自动重启
- 如果需要手动选启动项：
  - 4029GP：用 IPMI KVM 里的虚拟键盘按 F11，进入启动菜单
  - GA-X99-UD4：本地键盘按 F12，进入启动菜单
- 选择 `proxmox (...)` 或安装目标 SSD 对应的 UEFI 启动项
- 系统会从 1TB SSD 启动，控制台上会显示：
  - 管理 URL：https://你的IP:8006
  - Hostname 等信息
  - 记下 URL，后面要用浏览器访问

## 首次登录 Web 界面

### 在笔记本上打开浏览器

- 访问 https://<PVE服务器IP>:8006
- 例如 `https://192.168.31.103:8006`
- 证书是自签名的，浏览器会提示不安全，选高级 → 继续访问。

### 登录

- 用户名：`root`
- 密码：安装时设置的
- Realm 先用 `Linux PAM` 或 `Proxmox VE authentication server` 都行。

### 订阅提示
- 第一次登录会弹出 “No valid subscription” 的提示
- 直接点 OK 忽略即可（可以后面改成 no-subscription 源）。

## 将系统盘配置为 VM 存储

::: tip Proxmox VE Installation - Advanced LVM Configuration Options:
- https://pve.proxmox.com/pve-docs/chapter-pve-installation.html#advanced_lvm_options

Proxmox VE Storage:
- https://pve.proxmox.com/pve-docs/chapter-pvesm.html

Proxmox VE Logical Volume Manager (LVM):
- https://pve.proxmox.com/wiki/Logical_Volume_Manager_(LVM)
:::

如果服务器里只有一块 Zhitai 1TB SSD，可以直接使用 PVE 安装器默认创建的 `local-lvm` 来放 VM/CT 磁盘，不需要再单独创建 `vmdata`。

PVE 选择 `ext4` 或 `xfs` 安装时，安装器会在系统盘上创建一个叫 `pve` 的 LVM Volume Group，并在里面创建：

- `root`：PVE 系统盘，挂载为 `/`
- `swap`：交换分区
- `data`：LVM-thin thin pool，在 Web UI 里显示为 `local-lvm`

安装完成后，默认存储通常是：

- `local`
  - 类型：Directory
  - 路径：`/var/lib/vz`
  - 用途：ISO image、Container template、Backup、Snippets
  - 物理位置：同一块 1TB SSD 上的 `root` LV
- `local-lvm`
  - 类型：LVM-Thin
  - 后端：`pve/data`
  - 用途：Disk image、Container
  - 物理位置：同一块 1TB SSD 上的 `data` thin pool

也就是说：
- ISO 上传到 `local`
- VM/CT 磁盘放到 `local-lvm`
- 不要删除或禁用 `local-lvm`，它就是单盘部署时运行 VM 的主存储

### 磁盘选项

在 PVE 安装器的 `Target Harddisk` > `Options` 里：

- `Filesystem`：选 `ext4`（默认）或 `xfs`
- `hdsize`：默认即可，表示整块 1TB SSD 都给 PVE 使用
- `swapsize`：默认即可；如果内存很大，也可以手动设为 `8`
- `maxroot`：建议 `96` 或默认
  - 官方默认策略里，大于 48 GiB 的盘会把 `root` 控制在 `hdsize / 4`，最大 96 GiB
  - 只放少量 ISO/模板时，96 GiB 通常够用
  - 如果你打算把大量 ISO、模板、临时备份也放本机，可以适当调大，但会减少 VM 磁盘空间
- `minfree`：默认即可；1TB 盘会默认在 VG 里留一部分未分配空间
- `maxvz`：默认留空即可，让剩余空间尽量分给 `data` / `local-lvm`

不要把 `maxvz` 设为 `0`。官方文档说明，`maxvz=0` 会导致不创建 `data` 卷，也就不会有默认的 `local-lvm` VM 磁盘池。

### 检查存储

登录 Web UI 后：

- 左侧点 `Datacenter`
- 右侧打开 `Storage`
- 确认有两行：
  - `local`，Type 是 `Directory`
  - `local-lvm`，Type 是 `LVM-Thin`
- 选中 `local-lvm` > `Edit`
  - `Content` 至少勾选 `Disk image`、`Container`

也可以在节点 Shell 里看：

```sh
pvesm status
lvs
```

输出一般类似：

```sh{4}
root@pve:~# pvesm status
Name             Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
local             dir     active        98497780         3849496        89598736    3.91%
local-lvm     lvmthin     active       794337280               0       794337280    0.00%
```

`lvs` 里应该能看到类似：

```sh
data pve twi-a-tz--
root pve -wi-ao----
swap pve -wi-ao----
```

### 创建 VM

- 上传 ISO：
  - `Datacenter` > `pve` > `local` > `ISO Images`
  - 点击 `Upload`
- 创建 VM：
  - `Create VM`
  - `OS` 页面选择刚上传到 `local` 的 ISO
  - `Disks` 页面：
    - `Storage` 选 `local-lvm`
    - 磁盘大小按 VM 需求填写

这样 VM 的虚拟磁盘会直接创建在系统盘同一块 SSD 的 `pve/data` thin pool 上。

### 单盘部署注意事项

- 单盘没有冗余：Zhitai 1TB SSD 坏了，PVE 系统和 VM 磁盘都会一起丢
- 不建议把长期备份放在同一块盘的 `local`
  - 备份会占用 `root` LV 空间
  - 更建议备份到 NAS、移动硬盘、另一台 PVE 或 Proxmox Backup Server
- `local-lvm` 是块存储，不是普通目录
  - Web UI 里不会像 `local` 那样浏览文件
  - 这是正常现象，VM 磁盘由 PVE/LVM 管理
- LVM-thin 支持快照和 thin provisioning，但不要长期把空间打满
  - 建议定期看 `pvesm status`
  - `local-lvm` 使用率接近 80% 以后就要清理、迁移或扩容

## 将 4TB SSD 配置为 VM 存储

现在 1TB 上已经有一个默认的 local 和 local-lvm 存储了，我们接下来把 4TB SSD 加成一个新的 LVM-Thin 存储，比如叫 vmdata，专门放虚拟机/容器磁盘。

### 在 PVE 里识别 4TB SSD

- 在左侧点击节点，`Datacenter` > `pve`）
- 点击右侧一级选项卡 `Disks`，可以看到：
  - 1TB 那块盘（上面已经有 pve 的分区）；
  - 4TB 那块 空盘（Size ~3.84T，Model 显示 `INTEL SSDPF2KX038TZ`）。
  - 如果 4TB 之前用过，可能会有旧分区/数据，下面先清理

### 初始化 4TB 磁盘（GPT）

在 Disks 菜单下：
- 选中那块 4TB SSD；
- 如果有旧分区：
  - 点击 `Wipe Disk`，确认清空（会删除盘上所有数据，确保无重要数据）
- 点击 `Initialize Disk with GPT`
  - 选中 4TB 盘，确认执行
- 这样磁盘就有一个干净的 GPT 分区表，后面好做 LVM。

### 创建 LVM-Thin Thinpool（vmdata）

继续在同一个节点 `pve` 下操作：
- 切到 `LVM-Thin` 选项卡
- 点击右上角 `Create: Thinpool`
- 在弹窗中：
  - Name：比如写 `vmdata`；
  - Disk：选你的 4TB SSD (类似 `/dev/nvme0n1`)
  - 其他默认（Proxmox 会自动创建 VG+Thinpool 结构）
  - 建议勾选添加存储（默认）
- 点击 `Create` 完成。

这样系统就会在 4TB 盘上创建：
- 一个 Volume Group
- 其中的一个 Thin Pool（如 vmdata）

### 在 Datacenter 里检查/添加存储条目

有的版本创建 Thinpool 时会顺带在 Storage 里创建存储，有的不会，我们检查一下：
- 左侧点 `Datacenter`，然后在右侧选项卡里点 `Storage`
- 会显示一个表格，包含 `ID`, `Type` (Directory/LVM-Thin), `Content` 等列
- 查看是否有一行，`ID` 为 `vmdata(pve)`，`Type` 为 `LVM-Thin`，
  - 如果有：
    - 选中它，点击 Edit，确认：
      - `Content` 至少勾选：`Disk image`、`Container`（想用它放 VM/CT 磁盘的话）
      - `Nodes` 勾上当前节点（`pve`）
  - 如果没有：
    - 点表格左上方的 `Add`，下拉菜单里选择 `LVM-Thin`
    - ID：`vmdata`
    - Volume group / Thin pool：选择在前一步创建的 VG/Thinpool
    - Nodes：勾上当前节点（`pve`）
    - Content：勾选`Disk image`、`Container`
    - 保存。

至此，4TB 盘就已经作为 vmdata 存储挂载成功了，后面建 VM 时就能选。

### 命令行

点击 `Datacenter` > `pve` > `>_ Shell`，即可打开命令行终端。

查看 LVM 信息：
```sh
pvesm status
```

输出形如：

```sh{5}
root@pve:~# pvesm status
Name             Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
local             dir     active        98497780         3849496        89598736    3.91%
local-lvm     lvmthin     active       794337280               0       794337280    0.00%
vmdata        lvmthin     active      3717050368               0      3717050368    0.00%
```

如果看到类似下面的输出，就说明 vmdata 这个 LVM-Thin 存储已经被 PVE 正确识别了：

```sh
vmdata  lvmthin  active  ...  
```

### 调整默认存储策略（让 VM 默认走 4TB 盘）

安装完后，系统盘上的存储一般是这样的：
- local（Directory）：
  - 内容：ISO image, Container template, Backup, Snippets 等；
- local-lvm（LVM-Thin）：
  - 内容：Disk image, Container；
  - 物理上在 1TB SSD 上。

而你希望 VM 的磁盘都放在 4TB 的 vmdata 上，所以可以做两件事：
- 禁用 local-lvm 的 VM 用途
  - Datacenter → Storage → 选 local-lvm → Edit；
  - 在 Content 里把 Disk image 和 Container 都取消勾选（或者干脆删除这个存储条目，如果你完全不想用）。
  - 这样以后新建 VM 时就不会默认落到 1TB 上。
- 确保 vmdata 可用作默认 VM 存储
  - 在 vmdata 的 Edit 里确认已经勾选 Disk image、Container；
  - 有多个存储时，新建 VM 的窗口里会允许你选，这时选 vmdata 即可。

## 换源

Proxmox - USTC Mirror Help
https://mirrors.ustc.edu.cn/help/proxmox.html

查看当前源：

```sh
grep -R "enterprise.proxmox.com" /etc/apt/sources.list* /etc/apt/sources.list.d -n
```

创建下面的脚本：

```sh
# at: /root
touch ./pve_sources.sh && chmod +x ./pve_sources.sh && nano ./pve_sources.sh
```

写入下面的内容：

<<< @/notes/scripts/pve_sources.sh{sh}

运行脚本，并更新源：

```sh
./pve_sources.sh
apt update
```

如果成功，输出形如：

```sh
Hit:1 http://mirrors.ustc.edu.cn/debian trixie InRelease
Hit:2 http://mirrors.ustc.edu.cn/debian trixie-updates InRelease                                                                        
Hit:3 https://mirrors.ustc.edu.cn/proxmox/debian/ceph-squid trixie InRelease                             
Hit:4 https://mirrors.ustc.edu.cn/proxmox/debian/pve trixie InRelease              
Hit:5 http://security.debian.org/debian-security trixie-security InRelease         
```

## 创建 VM

参考：[PVE 创建 Ubuntu 虚拟机](./pve-ubuntu.md)

## qve 运维经验：bj123 自启、HDD 存储和网卡稳定性

本节记录 qve 上运行 bj123 时遇到的几个问题。示例保留 `qve` 和 `bj123` 这两个主机名；IP、密码、磁盘序列、tailnet 域名等敏感信息不要写入文档，实际执行时用占位符替换。

### Start at boot 早于 HDD 挂载

现象：

```text
TASK ERROR: unable to activate storage 'hdd8t' - directory is expected to be a mount point but is not mounted: '/mnt/hdd8t'
```

原因：

- PVE 的 `pve-guests.service` 会在开机时执行 `startall`。
- 如果 VM 的某块虚拟磁盘放在 Directory Storage，例如 `hdd8t`，而这个 storage 对应的 `/mnt/hdd8t` 还没挂载完成，PVE 会拒绝激活该 storage。
- `/etc/fstab` 中如果对 HDD 使用了 `nofail`，系统不会为了它阻塞整个 boot 流程，导致 `pve-guests.service` 可能抢跑。

检查：

```sh
qm config <VM_ID>
sed -n '1,220p' /etc/pve/storage.cfg
sed -n '1,220p' /etc/fstab
findmnt <PVE_HDD_MOUNTPOINT>
systemctl status pve-guests.service --no-pager -l
systemctl status mnt-hdd8t.mount --no-pager -l
journalctl -b -u pve-guests.service -u mnt-hdd8t.mount --no-pager
```

修复方式：给 `pve-guests.service` 增加 drop-in，明确要求 VM 自启前等待 HDD mount point。

```sh
mkdir -p /etc/systemd/system/pve-guests.service.d
nano /etc/systemd/system/pve-guests.service.d/10-wait-for-hdd8t.conf
```

写入：

```ini
[Unit]
RequiresMountsFor=/mnt/hdd8t
After=mnt-hdd8t.mount

[Service]
ExecStartPre=
ExecStartPre=-/usr/share/pve-manager/helpers/pve-startall-delay
ExecStartPre=/bin/sh -c 'for i in $(seq 1 300); do mountpoint -q /mnt/hdd8t && exit 0; echo "waiting for /mnt/hdd8t before starting PVE guests ($i/300)"; sleep 1; done; echo "/mnt/hdd8t is not mounted; refusing to start PVE guests" >&2; exit 1'
```

应用并验证：

```sh
systemctl daemon-reload
systemd-analyze verify pve-guests.service
systemctl cat pve-guests.service
```

如果 VM 需要自启：

```sh
qm set <VM_ID> --onboot 1 --startup order=10
qm config <VM_ID> | grep -E '^(onboot|startup):'
```

### e1000e 管理网卡 Hardware Unit Hang

现象：

- 局域网内无法访问 PVE Web UI、SSH 和 VM。
- VM 内部来不及记录明显错误。
- PVE 重启后，前一个 boot 的 journal 末尾反复出现：

```text
e1000e 0000:00:19.0 nic0: Detected Hardware Unit Hang
```

排查命令：

```sh
journalctl --list-boots --no-pager
journalctl -b -1 -k --since '<LOCAL_TIME_START>' --until '<LOCAL_TIME_END>' --no-pager
journalctl -b -1 -k -p warning..alert --no-pager
lspci -nnk | sed -n '/Ethernet controller/,+8p'
ethtool -i nic0
ethtool -k nic0
ethtool --show-eee nic0
```

判断：

- 如果故障窗口的最后日志持续刷 `e1000e ... Detected Hardware Unit Hang`，但没有先出现 MCE、thermal shutdown、OOM、NVMe timeout、kernel panic 等日志，优先怀疑宿主机管理网卡或驱动卡死。
- qve 这里的管理网卡是 Intel I218-V，驱动为 `e1000e`，并作为 `vmbr0` 的 bridge port。Linux bridge/vhost 流量叠加 TSO/GSO/GRO/checksum/EEE 时，可能触发这种硬件队列 hang。

保守修复：关闭这类 offload 和 EEE，并做持久化。

```sh
nano /usr/local/sbin/qve-nic0-stability.sh
chmod +x /usr/local/sbin/qve-nic0-stability.sh
```

脚本：

```sh
#!/bin/sh
set -eu
IFACE="${1:-nic0}"
[ -d "/sys/class/net/$IFACE" ] || exit 0

if command -v ethtool >/dev/null 2>&1; then
  ethtool -K "$IFACE" tso off gso off gro off sg off tx off rx off 2>/dev/null || true
  ethtool -K "$IFACE" rxvlan off txvlan off 2>/dev/null || true
  ethtool --set-eee "$IFACE" eee off 2>/dev/null || true
  ethtool -s "$IFACE" wol d 2>/dev/null || true
fi
```

systemd 服务：

```sh
nano /etc/systemd/system/qve-nic0-stability.service
```

```ini
[Unit]
Description=Apply stable settings for qve Intel e1000e management NIC
Documentation=man:ethtool(8)
Requires=sys-subsystem-net-devices-nic0.device
After=sys-subsystem-net-devices-nic0.device network-pre.target
Before=pve-guests.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/qve-nic0-stability.sh nic0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

if-up hook，防止接口重新 up 后 offload 恢复默认：

```sh
nano /etc/network/if-up.d/qve-nic0-stability
chmod +x /etc/network/if-up.d/qve-nic0-stability
```

```sh
#!/bin/sh
[ "${IFACE:-}" = "nic0" ] || exit 0
/usr/local/sbin/qve-nic0-stability.sh nic0 >/dev/null 2>&1 || true
exit 0
```

可选 modprobe 参数：

```sh
cat >/etc/modprobe.d/e1000e-stability.conf <<'EOF'
options e1000e SmartPowerDownEnable=0
EOF
```

应用并验证：

```sh
systemctl daemon-reload
systemctl enable --now qve-nic0-stability.service
ethtool -k nic0 | grep -E 'rx-checksumming|tx-checksumming|scatter-gather|tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload|rx-vlan-offload|tx-vlan-offload'
ethtool --show-eee nic0
journalctl -k --since '<FIX_TIME>' --no-pager | grep -E 'Detected Hardware Unit Hang|NETDEV WATCHDOG'
```

如果后续仍复现，下一步更根本的方案是改用独立 Intel server NIC，或把 PVE 管理口迁到另一块更稳定的网卡。

### GPU 直通的 rombar 经验

如果某张 GPU 是宿主机 boot VGA 或在 VM 启动时对 option ROM 敏感，直通给纯 SSH/计算 VM 时可以禁用 ROM BAR：

```sh
qm set <VM_ID> --hostpci<N> '<GPU_PCI_ADDRESS>,pcie=1,rombar=0'
qm set <VM_ID> --vga none
```

qve 上 bj123 的 4090 曾经需要 `rombar=0` 才稳定启动。删除这个选项后，VM 可能仍能保存配置，但下一次启动存在失败或卡住风险。验证方式：

```sh
qm config <VM_ID> | grep '^hostpci'
qm start <VM_ID>
qm status <VM_ID> --verbose
```

VM 运行后，可以在 QEMU 命令行确认参数是否实际生效：

```sh
PID="$(qm status <VM_ID> --verbose | awk '/^pid:/ {print $2}')"
tr '\0' ' ' < "/proc/$PID/cmdline" | grep -o 'host=<GPU_PCI_ADDRESS>[^ ]*\|rombar=0'
```

### 大内存 VM 的启动速度

把宿主机几乎全部内存分给单个 VM 会让启动变慢，也会挤压 PVE 管理面。bj123 的默认值建议用 96 GiB：

```sh
qm set <VM_ID> --memory 98304
```

如果 VM 正在运行，配置会先写入 PVE，通常要等下次 VM 重启后运行态 `maxmem` 才会变成新的值：

```sh
qm config <VM_ID> | grep '^memory:'
qm status <VM_ID> --verbose | grep -E '^(maxmem|mem|freemem):'
```
