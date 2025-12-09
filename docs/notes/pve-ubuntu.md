# PVE 创建 Ubuntu 虚拟机

概览：准备 ISO、安装 Ubuntu、加大容量数据盘
前置：已经有 `vmdata` 的 LVM-Thin （需要正确选择它来放系统盘）

## 一、准备 Ubuntu 22.04 ISO 镜像

1. 在自己电脑中下载 `Ubuntu 22.04 LTS`：
   - Ubuntu 22.04.5 LTS (Jammy Jellyfish)
     - https://releases.ubuntu.com/jammy/
   - Desktop image
     - https://releases.ubuntu.com/jammy/ubuntu-22.04.5-desktop-amd64.iso

2. 把下载好的 ISO 上传到 PVE 的 `local` 存储：
   - 在 PVE 网页左侧点击 `Datacenter` → 节点 `pve` → 选中 `local (pve)` 
   - 点击选项卡 `ISO Images` → 点击左上角 `Upload`
   - `Select File` → 选择刚下载的 `ubuntu-22.04.5-desktop-amd64.iso`
   - 点击 `Upload`，等待上传完成
   - 传完后在 `ISO Images` 列表里可以看到这个 ISO 文件
   * 也可以用 `Download from URL`，但现在有 ISO 可以直接用 Upload
   * iso 文件默认存储在：`/var/lib/vz/template/iso`

## 二、创建 Ubuntu 22.04 虚拟机

要求：系统盘放在 `vmdata` 上。

- 在左侧 `Server View` 的树状结构中，选中节点 `pve`
- 右上角点击 `Create VM`

### 1. General 选项卡

* `Node`：默认就是 `pve`
* `VM ID`：默认是 `101`（保证不和现有的冲突）
* `Name`：比如 `AI-122`
  * `AI` 表示用途
  * `122` 表示后面要在内部分配的 IP 后缀
* 其他保持默认，点 `Next`

### 2. OS 选项卡

* 勾选 `Use CD/DVD disc image file (iso)`
  * `Storage`：选 `local`（就是刚刚上传 ISO 的存储）
  * `ISO image`：选 `ubuntu-22.04.5-desktop-amd64.iso`
  * `Guest OS`：
    * `Type` 选 `Linux`
    * `Version`：选 `6.x - 2.6 Kernel` 或 `Ubuntu`（有的话）
* 点 `Next`

### 3. System 选项卡

这里主要是启动方式和控制器。

* `Graphic card`：默认 `Default`
* `Machine`：选择 `q35`
  * `q35` 模拟更新的 Intel Q35 芯片组，支持 GPU 直通、NVMe 直通，多种 PCIe 设备拓扑时更好
  * `i440fx` 兼容性比较好，但是不支持原生 PCIe 拓扑，做直通和现代设备比较麻烦
* `BIOS`：
  * 推荐 `OVMF (UEFI)`，方便以后用 UEFI；
  * 如果你有特别要求，也可以保留 `SeaBIOS`。
* `SCSI Controller`：选 `VirtIO SCSI single`（性能好，也是官方推荐）
* 勾选 `QEMU Agent`（非常推荐，后面方便看到 IP、优雅关机等）
  - 后续可能还需要在 Ubuntu 中运行如下命令：
    ```sh
    sudo apt update
    sudo apt install qemu-guest-agent
    sudo systemctl enable --now qemu-guest-agent
    ```
* 点 `Next`

### 4. Disks 选项卡

关键：把系统盘放到 `vmdata`（3.84TB SSD）

* `Bus/Device`：选 `SCSI`。
* `Storage`：选择 `vmdata`
  * 这样这个虚拟磁盘会建在 `/dev/nvme1n1` 上的 LVM-Thin 里
* `Disk size`：按需设置，比如 `2048 GB`
  * 将来可以扩大，但是不能缩小
  * 扩容还是有点麻烦的，需要做分区和扩容操作，尽量第一次就给够
* 勾选 `Discard`：TRIM/UNMAP，当虚拟机中删除文件时，PVE 可以把释放的空间真正还给底层 LVM-Thin
* `Cache`：默认 `No cache`，稳定安全
* 点开 `Advanced`
   * 勾选 `SSD emulation`：可以让虚拟机识别这块盘是 SSD，可以优化性能
* 点 `Next`

### 5. CPU 选项卡

* `Sockets`：默认为 `1`
  * 对于 Linux，绝大多数情况下，1 个 Socket + 多个 Core 就可以了
* `Cores`：
  * 用如下命令查看宿主机 CPU 核心数：
  ```sh
  egrep '^processor' /proc/cpuinfo | sort -u | wc -l
  ```
  * 假设上面命令输出为 `104`，可以考虑给个 `32`
* `Type`：
  * 推荐选 `host`：性能好，尤其是目前是单节点用 PVE，又是较新的 Ubuntu 22.04
  * 如果以后有多节点、要做热迁移，可以选 `x86-64-v2-AES`，兼容性更好
* 点开 `Advanced`：
  * `vCPUs`：保持默认即可（可以删除掉值，会自动计算为 Sockets × Cores）
  * `NUMA`：不用开，不必引入复杂性
* 点 `Next`

### 6. Memory 选项卡

* `Memory (MiB)`：比如设为 `1048576` (`1TB`)
* 点开 `Advanced`：
  * `Ballooning`：默认勾选
  * `Allow KSM`：默认勾选
* 点 `Next`

### 7. Network 选项卡

* `Bridge`：选择默认的即可
  * 默认是已经配置好的 Linux Bridge，比如左边树结构中的 `localnetwork (pve)` 一般对应 `vmbr0`
* `Model`：选 `VirtIO (paravirtualized)`，性能更好
* 点 `Next`

### 8. Confirm 选项卡

* 检查一下：
  * `ide2` 是 `local:iso/ubuntu-22.04.5-desktop-amd64.iso,media=cdrom`
  * `efidisk0` 是 `vmdata`
* 确认无误后，点 `Finish` 创建 VM

此时 VM 已经建好，但系统还没装。

## 三、在 VM 里安装 Ubuntu 22.04

* 在左侧的树结构中，选择刚创建的 VM（比如 `101 (AI-122)`）
* 点击上方 `Start` 启动
* 点击 `Console` 下拉列表，选择 `noVNC` 打开控制台
* 会从 ISO 启动进入 Ubuntu 安装界面：
   * 如果电脑的分辨率不够，需要滚动右侧的滚动条来看下方的选项
   * 语言选择 `English`，点击 `Install Ubuntu`
   * 选择键盘布局 `English (US)`
   * 选择 `Normal installation`
   * 取消勾选 `Download updates while installing Ubuntu`（后面可以手动更新）
   * 分区时选 `Erase disk and install Ubuntu`：
     * 这里看到的“磁盘”是刚刚在 `vmdata` 上创建的虚拟磁盘，不是宿主机的物理盘，放心选
   * 选择时区：`Shanghai`
   * 设置主机名、用户、密码等
     * `Your Name`：
     * `Your computer's name`：`ai122`
     * `Pick a username`：
     * `Choose a password`：
     * `Confirm your password`：
     * 勾选 `Log in automatically`（方便使用）
   * 等待安装完成
   * 可选：勾选安装 OpenSSH Server（以后方便用 SSH 登入）
   * 等待安装完成，点击 `Restart Now` 重启
   * 此时会提示 `Please remove the installation medium, then press ENTER`
* 移除 ISO / 调整启动顺序（避免下次还从光驱启动）
   * 在 PVE 左侧选中该 VM → 点击选项卡 `Hardware`
   * 找到 `CD/DVD Drive` → `Edit`：
     * 选 `Do not use any media`，点 OK
   * 然后点击选项卡 `Options` → `Boot Order` → `Edit`：
     * 确保 `scsi0`（系统盘）排在第一行
   * 回到 Console 的那个提示界面，回车，应该就可以直接从安装好的系统启动
* 登录系统，点击 `Activities` → 搜索 `Terminal` 打开终端，并且添加到 Favorites 方便以后打开
* 点击右上角电源图标，选择 `Settings`
  * `Appearance` → 选择 `Dark` 主题
  * `Power` → `Power Saving Options`
    * `Screen Blank` 设为 `Never`
    * `Automatic suspend` 设为 `Off`（避免虚拟机自动休眠）
  * `Network` → `Wired` → 点击 `Connected` 右边的设置图标 → `IPv4`：
    * `IPv4 Method` 选 `Manual`
    * `Addresses`：
      * `Address`：`192.168.31.122`
      * `Netmask`：`255.255.255.0`
      * `Gateway`：`192.168.31.1`
    * `DNS`：取消勾选 `Automatic`，填入 `192.168.31.1`
    * 点击 `Apply` 保存
    * 重启以使得静态 IP 地址设置生效
  * 或者在命令行中修改网络：参考 [Ubuntu 设置静态 IP](./ip-static.md)
    ```sh
    # 查看连接名称
    nmcli connection show
    
    # 假如输出 Name: Wired connection 2 (DEVICE：enp10s18)
    CONN_NAME="Wired connection 2"
    
    # 设置静态 IP
    sudo nmcli connection modify "$CONN_NAME" ipv4.addresses 192.168.31.122/24 ipv4.gateway 192.168.31.1 ipv4.dns 192.168.31.1 ipv4.method manual
    
    # 重启连接以使设置生效
    sudo nmcli connection down "$CONN_NAME" && sudo nmcli connection up "$CONN_NAME"
    ```

## 一些常用配置

### 换源

参考：[Ubuntu 换国内源](./ubuntu-sources.md)

::: tip USTC Mirror Help
- https://mirrors.ustc.edu.cn/help/ubuntu.html
:::

```sh
sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list

# 一般不建议替换 security 源
# 镜像站同步有延迟，可能会导致生产环境不能及时安装上最新的安全更新
sudo sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

# 使用 HTTPS 避免运营商缓存劫持
sudo sed -i 's/http:/https:/g' /etc/apt/sources.list
```

更新软件包列表：

```sh
sudo apt update
```

### 开启SSH

参考：[Ubuntu 开启 SSH服务](./ubuntu-ssh.md)

安装：

```sh
sudo apt install openssh-server
```

启动：

```sh
sudo systemctl enable ssh --now
```

查看服务状态：

```sh
sudo systemctl status ssh
```

之后就可以通过 SSH 登录这台虚拟机了。

### 安装 Merak

参考：[使用 Merak 组网](./merak.md)

之后就可以通过 Merak 远程访问这台虚拟机了。

### 安装 tmux

参考：[安装 tmux](./tmux.md)

### 安装 zsh

参考：[安装 zsh](./zsh.md)

### 安装 v2ray

参考：[安装 v2ray](./v2ray.md)

### 安装 conda + Python

参考：[安装 conda](./conda.md), [Python 依赖管理](./python-requirements.md)

### 安装 git

参考：[安装 git](./git.md)

## 四、在 Ubuntu 内安装 QEMU Guest Agent（建议）

如果在创建 VM 时已经勾了 `QEMU Guest Agent`，现在只需要在 VM 里安装软件。
1. 在 PVE 里确认选项：
   * 选中 VM （`AI-122`）→ `Options` → `QEMU Guest Agent`
   * 确保状态为 `Enabled`，如果不是就 `Edit` 勾上
2. 在 Ubuntu 里执行（通过 Console 或 SSH）：
   ```bash
   sudo apt update
   sudo apt install qemu-guest-agent
   sudo systemctl enable --now qemu-guest-agent
   ```
3. 稍等几秒，在 PVE 中，选择 VM（比如 `ai122`）的 `Summary` 选项卡，就能看到 IP 等信息自动显示

## 五、启用显卡直通，并将分配给 VM

### 在 PVE 9 上启用 IOMMU

```sh
nano /etc/kernel/cmdline
```

添加：

```sh
intel_iommu=on iommu=pt
```

运行：

```sh
proxmox-boot-tool refresh
```

重启 PVE：

```sh
reboot
```

确认 IOMMU 状态：

```sh
dmesg | grep -e DMAR -e IOMMU -e AMD-Vi | grep -i ioomu
```

如果输出中看到类似 `IOMMU enabled` 的内容，就说明 IOMMU 启用成功。

输出形如：

```sh
[    9.191140] DMAR-IR: IOAPIC id 12 under DRHD base  0xc5ffc000 IOMMU 6
[    9.191142] DMAR-IR: IOAPIC id 11 under DRHD base  0xb87fc000 IOMMU 5
[    9.191144] DMAR-IR: IOAPIC id 10 under DRHD base  0xaaffc000 IOMMU 4
[    9.191146] DMAR-IR: IOAPIC id 18 under DRHD base  0xfbffc000 IOMMU 3
[    9.191147] DMAR-IR: IOAPIC id 17 under DRHD base  0xee7fc000 IOMMU 2
[    9.191149] DMAR-IR: IOAPIC id 16 under DRHD base  0xe0ffc000 IOMMU 1
[    9.191151] DMAR-IR: IOAPIC id 15 under DRHD base  0xd37fc000 IOMMU 0
[    9.191152] DMAR-IR: IOAPIC id  8 under DRHD base  0x9d7fc000 IOMMU 7
[    9.191154] DMAR-IR: IOAPIC id  9 under DRHD base  0x9d7fc000 IOMMU 7
```

### 加载 VFIO 模块

```sh
nano /etc/modules
```

在末尾添加：

```sh
vfio
vfio_pci
vfio_iommu_type1
vfio_virqfd
```

### 黑名单宿主机显卡驱动

::: warning 
注意：如果宿主机还需要用某块卡输出图形，就不要把那一块卡对应的驱动全黑名单。
理想情况是宿主机用主板自带 iGPU 或 IPMI，把 8 块独显全部给 VM。
:::

对于 NVIDIA 显卡：

```sh
echo "blacklist nouveau"  > /etc/modprobe.d/blacklist-nouveau.conf
echo "blacklist nvidia"   > /etc/modprobe.d/blacklist-nvidia.conf
echo "blacklist nvidiafb" > /etc/modprobe.d/blacklist-nvidiafb.conf
```

### 将显卡全部绑定到 vfio-pci

查看显卡列表：

```sh
lspci -nn | grep -E "VGA|3D|Display"
```

输出形如：

```sh
03:00.0 VGA compatible controller [0300]: ASPEED Technology, Inc. ASPEED Graphics Family [1a03:2000] (rev 41)
1a:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
1b:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
3d:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
3e:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
88:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
89:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
b1:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
b2:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
d8:00.0 Non-Volatile memory controller [0108]: Intel Corporation NVMe DC SSD [3DNAND, Sentinel Rock Controller] [8086:0b60]
d9:00.0 Non-Volatile memory controller [0108]: Intel Corporation NVMe DC SSD [3DNAND, Sentinel Rock Controller] [8086:0b60]
```

- 方括号里的 `10de:2206` 就是 `vendor:device` ID。
- 对同型号的 8 块卡，这个 ID 往往都是一样的。

```sh
# 很多显卡有独立的音频功能
lspci -nn | grep -i audio
```

输出形如：

```sh
1a:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
1b:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
3d:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
3e:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
88:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
89:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
b1:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
b2:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
```

- 这里的 `10de:1aef` 就是音频部分的 `vendor:device` ID。

查看 IOMMU 组：

```sh
find /sys/kernel/iommu_groups/ -type l
```

- 确认没有和别的重要设备绑在一起
- 因为是“8 块卡都给同一台 VM”，即便多块卡在同一个 IOMMU 组里，问题也不大
- 只要组里别混着 SATA 控制器之类宿主机必须用的设备

将这些卡全部绑定到 vfio-pci：

```sh
nano /etc/modprobe.d/vfio.conf
```

添加：

```sh
options vfio-pci ids=10de:2206,10de:1aef
```

重新生成 initramfs：

```sh
update-initramfs -u
```

重启：

```sh
reboot
```

重启之后确认每块 GPU 已经绑定到 vfio-pci：

```sh
# lspci -nnk | grep -A3 -E "VGA|3D|Display"
lspci -nnk | grep -A3 -E "NVIDIA" | grep -i kernel
```

输出形如：

```sh
Kernel driver in use: vfio-pci
# Kernel modules: nvidiafb, nouveau
# Kernel modules: snd_hda_intel
```

这就说明宿主机已经把显卡让出来了。

### 将显卡全部直通给 VM

现在开始在 PVE 的 Web 界面操作。

左侧树结构选中 VM （比如 `ai122`）→ `Hardware` 选项卡：
- 确认 `BIOS: OVMF (UEFI)`
- 确认 `Machine: q35`
- 点击 `Add` 下拉列表 → 选择 `PCI Device`
- 选择 `Raw Device`，点击出现列表，点选 `IOMMU Group` 正向排序（一般 GPU 都排在靠前的组）
- 在列表里选第一块 GPU
  - 同一块 GPU 通常会有一个 VGA + 一个 Audio
  - 勾选 `All Functions`，让 PVE 自动把同一张卡的所有函数一起直通
  - 不勾 `Primary GPU`：
    - 如果只是算力卡，用远程 SSH，不用勾选
    - 如果想用这块卡做虚拟机的显示输出（接显示器），可以在其中一块卡上勾
  - 点开 `Advanced`
    - 勾选 `PCI-Express`（q35 + 现代 GPU）
  - 确认无误，点击 `Add`
  - 添加好后，可以看到信息栏 `PCI Device` 多了一条记录，类似 `0000:3d:00,pcie=1`
- 重复上一步，把剩下的 7 块 GPU 都按同样方式加进来：
  - 每次 Add → PCI Device，选不同的 GPU / IOMMU 组。
  - 如果某几块卡在同一个 IOMMU 组里，PVE 会强制你把整个组都直通过去，这对“全给 ai122”来说是OK的
  - 可以先加 1 块卡，确认没问题后再加剩下的

### 验证 VM 中显卡是否已经直通

在 PVE 中选择 `AI-122`，点击 `Start`。

运行：

```sh
lspci -nn | grep -E "VGA|3D|Display"
```

输出形如：

```sh
00:01.0 VGA compatible controller [0300]: Device [1234:1111] (rev 02)
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
```

```sh
lspci -nn | grep -i audio
```

输出形如：

```sh
00:1b.0 Audio device [0403]: Intel Corporation 82801I (ICH9 Family) HD Audio Controller [8086:293e] (rev 03)
01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
```

这就表示已经成功直通了。

如果要添加新的 GPU，得先关闭 VM，再重复上面的“将显卡全部直通给 VM”的步骤。

### 安装 NVDIA 驱动和 NVCC+CUDA

参考：[Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)](./nvidia-driver.md)


## 常见问题

### 启动时间太长

例如：超过5分钟。

::: warning 【待解决】启用 IOMMU / Passthrough（直通）后，启动慢似乎是个已知问题

【Windows】PVE直通下的Windows开机巨慢的解决方案之一
- https://blog.csdn.net/Freesia_2350/article/details/146205627

Extremely slow VM startup when IOMMU/Passthrough is enabled
- https://www.reddit.com/r/Proxmox/comments/wowj61/extremely_slow_vm_startup_when_iommupassthrough
:::

::: tip 【已验证】似乎启动慢是因为给 VM 分配的内存太大，初始化需要很久
试试把 VM 的内存调小一些，比如从 1TB (1048576) 调到 128GB (131072) 或者 64GB (65536)。
:::

### 启动失败

::: tip 【已验证】试试 Remove 几张显卡。
:::


## 六、把 20TB HDD 配置成大容量数据存储并挂给 VM

你说想用 `/dev/sda` 这块 20TB HDD 来放大容量数据。典型做法是：

* 在 PVE 上用 `/dev/sda` 创建一个新的 LVM-Thin 存储（比如叫 `hdddata`）；
* 然后给某个 VM 新增一块硬盘，存放在 `hdddata` 上；
* VM 里把这块硬盘分区、格式化、挂载到 `/data` 之类。

### 1. 在 PVE 上用 /dev/sda 创建 LVM-Thin 存储

> 你已经会创建 `vmdata` 了，这个步骤类似，只是磁盘换成 `/dev/sda`。

1. 创建 Volume Group：

   * 左侧选 `pve` 节点 → `Disks` → `LVM`。
   * 上方点 `Create`：

     * `Disk`：选 `/dev/sda`。
     * `Name`：比如 `hdd-vg`。
     * 点 `Create`。

2. 在这个 VG 上创建 Thin Pool 并注册为存储：

   * 左侧仍在 `pve` 节点 → `Disks` → `LVM-Thin`。
   * 上方点 `Create`：

     * `Volume group`：选刚才的 `hdd-vg`。
     * `Name`（Thin pool 名）：比如 `hdd-thin`.
     * 勾选 `Add as Storage`。
     * `Storage ID`：比如 `hdddata`。
     * `Content`：勾选 `Disk image`（必要时再勾 `Container`）。
     * 点 `Create`。

3. 验证：

   * 到 `Datacenter` → `Storage`，应该能看到一条新的 `hdddata`（Type: LVM-Thin, Content: Disk image）。

### 2. 给刚才的 Ubuntu VM 加一块大容量数据盘（位于 HDD 上）

1. 左侧选中 Ubuntu 这台 VM → `Hardware`。

2. 上方点 `Add` → `Hard Disk`。

3. 在弹窗中设置：

   * `Bus/Device`：`SCSI`。
   * `Storage`：选你刚建立的 `hdddata`。
   * `Disk size`：比如 `2 TB`、`5 TB`、`10 TB`，看你需要（不一定一次用满 20TB）。
   * 其他保持默认，点 `Add`。

4. 启动 / 重启 VM。

### 3. 在 Ubuntu 内格式化和挂载这块新硬盘

假设新盘在 VM 里显示为 `/dev/sdb`（具体可以用 `lsblk` 看）。

1. 查看磁盘：

   ```bash
   lsblk
   ```

   找到那块没有分区的新盘，比如 `/dev/sdb`（无 `sdb1`）。

2. 建 GPT 分区和 ext4 文件系统（示例）：

   ```bash
   sudo parted /dev/sdb -- mklabel gpt
   sudo parted /dev/sdb -- mkpart primary ext4 0% 100%
   sudo mkfs.ext4 /dev/sdb1
   ```

3. 创建挂载点并挂载：

   ```bash
   sudo mkdir /data
   sudo mount /dev/sdb1 /data
   ```

4. 设为开机自动挂载（推荐用 UUID）：

   ```bash
   sudo blkid /dev/sdb1   # 记下输出里的 UUID
   sudo nano /etc/fstab
   ```

   在文件末尾添加一行（替换成你的 UUID）：

   ```text
   UUID=<上面查到的UUID>  /data  ext4  defaults  0  2
   ```

   保存退出后执行：

   ```bash
   sudo mount -a
   ```

   没报错就说明配置正常。

---

到这里：

* PVE 里已经有一台系统盘在 `vmdata`（3.84TB SSD 上）的 Ubuntu 22.04 VM；
* 可选地，你还把 20TB HDD 做成了 `hdddata` 存储，并给 VM 挂上了一个大容量数据盘。

如果你后面还想再建别的 VM，只要在“Create VM”的 `Disks` 页面记得把 Storage 选成 `vmdata`，它们的系统盘都会放在那块 3.84TB SSD 上；需要大盘时再从 `hdddata` 给它们加额外硬盘就行。
