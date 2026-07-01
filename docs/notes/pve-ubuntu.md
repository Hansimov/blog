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

#### 大内存 VM 的默认值经验

如果 VM 类似 `bj123`，主要用于 GPU/AI 任务，可以给较大的内存，但不一定要把宿主机内存几乎全部分给 VM。

经验值：

- 默认建议：`98304 MiB`，即 96 GiB。
- 需要更大内存任务时再临时调大，例如 120 GiB。
- 大内存 VM 启动时 QEMU 初始化和 guest 内存上报会更慢；从 120 GiB 调回 96 GiB 可以缩短启动等待。
- 宿主机应保留足够内存给 PVE、存储、网络和日志服务，避免管理面在 VM 压力下不可用。

命令行修改示例：

```sh
qm set <VM_ID> --memory 98304
```

如果 VM 正在运行，配置会写入 PVE；是否立即影响运行态取决于当前 balloon/hotplug 设置。最稳妥的判断方式是下一次重启 VM 后检查：

```sh
qm config <VM_ID> | grep '^memory:'
qm status <VM_ID> --verbose | grep -E '^(maxmem|mem|freemem):'
```

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

## 三a、软件环境配置

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

### 安装 tailscale

参考：[使用 Tailscale 组网](./tailscale.md)

之后就可以通过 Tailscale 远程访问这台虚拟机了。

### 安装 tmux

参考：[安装 tmux](./tmux.md)

### tmux-resurrect 恢复失败排查

在 `bj123` 这类纯 SSH/算力 VM 中，常用下面命令在登录后恢复 tmux：

```sh
tmux has-session 2>/dev/null || (tmux new-session -d && tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh)
```

如果预期是恢复上一次保存的所有 session/window/pane，但实际没有恢复，按下面顺序查：

```sh
tmux ls
ls -la ~/.tmux/plugins/tmux-resurrect/scripts/
ls -la ~/.local/share/tmux/resurrect/
readlink -f ~/.local/share/tmux/resurrect/last
sed -n '1,220p' ~/.tmux.conf
```

重点看两类问题：

- `last` 指向的保存文件是否本身就不完整。
  - `tmux-resurrect` 只会从 `~/.local/share/tmux/resurrect/last` 指向的文件恢复。
  - 如果某次崩溃后只保存了一个空 session 或很少的 pane，`last` 可能已经被覆盖成缩水版本。
  - 可以查看旧文件，选择最近一个完整文件重新指向：

```sh
cd ~/.local/share/tmux/resurrect
ls -lh tmux_resurrect_*.txt
ln -sfn tmux_resurrect_<TIMESTAMP>.txt last
```

- `.tmux.conf` 中是否有会破坏恢复流程的 hook。
  - `tmux-resurrect` 自己会处理从空 `session 0` 恢复时的清理。
  - 不要额外添加类似下面的 hook：

```tmux
set -g @resurrect-hook-pre-restore-pane-processes 'tmux kill-session -t=0 2>/dev/null || true'
```

这类 hook 会在 pane 恢复后、pane process 恢复前杀掉 `session 0`。而 `tmux new-session -d` 默认创建的 session 往往就是 `0`，结果可能是唯一 tmux server 被杀掉，恢复过程提前中断。

修复后可验证：

```sh
tmux kill-server 2>/dev/null || true
tmux has-session 2>/dev/null || (tmux new-session -d && tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh)
sleep 3
tmux ls
tmux list-windows -a
tmux list-panes -a -F 'session=#{session_name} window=#{window_index} pane=#{pane_index} path=#{pane_current_path} cmd=#{pane_current_command}'
```

### 安装 zsh

参考：[安装 zsh](./zsh.md)

### 安装 v2ray

参考：[安装 v2ray](./v2ray.md)

### 安装 conda + Python

参考：[安装 conda](./conda.md), [Python 依赖管理](./python-requirements.md)

### 安装 git

参考：[安装 git](./git.md)

### 安装 docker

参考：[安装 docker](./docker.md)

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

### 命令行一键直通

参考：[SLOT 和 GPU 对应关系](./nvidia-gpus.md#slot-和-gpu-对应关系)

清空旧的 hostpci 0-7：

```sh
for i in {0..7}; do qm set 101 -delete hostpci$i; done
```

设置新的 hostpci 0-7：

```sh
buses=(88 89 b1 b2 3d 3e 1a 1b); args=()
for i in "${!buses[@]}"; do args+=("-hostpci$i" "0000:${buses[$i]}:00,pcie=1"); done
qm set 101 "${args[@]}"
```

查看 VM 当前 PCI 设备：

```sh
qm config 101 | grep -E '^hostpci'
```

### 常见问题：`0 <= irq_num && irq_num < PCI_NUM_PINS`

问题详情：

```sh
kvm: ../hw/pci/pci.c:1815: pci_irq_handler: Assertion `0 <= irq_num && irq_num < PCI_NUM_PINS' failed.
TASK ERROR: start failed: QEMU exited with code 1
```

原因一般是掉卡。临时方案：<m>从 Hardware 的 PCI 设备列表中删除有问题的显卡。</m>

<details> <summary>解决方法（暂时无效）</summary>

解决方法：禁用上游端口省电。

```sh
nano /etc/kernel/cmdline
```

添加如下内容：

```sh
pcie_port_pm=off pcie_aspm=off vfio-pci.disable_idle_d3=1
```

- `pcie_port_pm=off`: 禁止 PCIe ports runtime PM（一般用于解决 device inaccessible）
- `pcie_aspm=off`: 关闭链路 ASPM（PLX/switch/riser 很多时需要该参数保证稳定）
- `vfio-pci.disable_idle_d3=1`: 不让 VFIO 管的设备在 idle 时进入 D3（避免 D3hot/D3cold → D0 失败）

也即修改后是：

```sh
intel_iommu=on iommu=pt pcie_port_pm=off pcie_aspm=off vfio-pci.disable_idle_d3=1
```

然后运行：

```sh
# proxmox-boot-tool refresh
# update-initramfs -u -k all
reboot
```

</details>

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


## 五a、常见问题

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

## 五b、智能启动脚本

### 启动 VM 时自动诊断和排除故障显卡

<details> <summary><code>start_vm101.sh</code></summary>

<<< @/notes/scripts/start_vm101.sh

</details>

## 六、把 20TB HDD 配置成大容量数据存储并挂给 VM

### 在 PVE 中查看磁盘信息

```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL
```

```txt{2}
NAME                            SIZE TYPE FSTYPE      MOUNTPOINT MODEL               SERIAL
sda                            18.2T disk                        WUH722020CLE604     PP****8P
nvme0n1                       894.3G disk                        INTEL SSDPF2KX960HZ PHA************QGN
├─nvme0n1p1                    1007K part
├─nvme0n1p2                       1G part vfat        /boot/efi
└─nvme0n1p3                     893G part LVM2_member
nvme1n1                         3.5T disk LVM2_member            INTEL SSDPF2KX038TZ PHA************AGN
├─vmdata-vmdata_tmeta          15.9G lvm
└─vmdata-vmdata_tdata           3.5T lvm
```

这里的 `/dev/sda` 就是 20TB 的 HDD。


查看详细信息：

```sh
fdisk -l /dev/sda
```

```txt
Disk /dev/sda: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
Disk model: WUH722020CLE604
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
```

### 清理磁盘

如果是全新空盘，这一步可以跳过。

```sh
wipefs -a /dev/sda
```

### 创建 GPT 分区和单一大分区

大容量适合 Directory 存储 + GPT 分区。

```sh
# apt install -y parted
parted -a optimal /dev/sda --script mklabel gpt
parted -a optimal /dev/sda --script mkpart primary ext4 1MiB 100%
partprobe /dev/sda
```

应当看到新分区 `/dev/sda1`：

```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT /dev/sda
```
```txt
NAME    SIZE TYPE FSTYPE MOUNTPOINT
sda    18.2T disk
└─sda1 18.2T part
```

### 格式化为 ext4

```sh
mkfs.ext4 -L hdd20t /dev/sda1
```

等待运行完成，然后检查：

```sh
lsblk --fs /dev/sda
```
```txt
NAME   FSTYPE FSVER LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda
└─sda1 ext4   1.0   hdd20t 9e******-****-****-****-**********7b
root@pve:~# blkid /dev/sda1
```

或者：

```sh
blkid /dev/sda1
```
```txt
/dev/sda1: LABEL="hdd20t" UUID="9e******-****-****-****-**********7b" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="primary" PARTUUID="e6******-****-****-****-**********5e"
```

这里的 `UUID` 就是后面要用来挂载的标识符。

### 挂载

创建挂载点：

```sh
mkdir -p /mnt/pve/hdd20t
```

启动时自动挂载：

```sh
nano /etc/fstab
```

添加一行：

```sh
UUID=9e******-****-****-****-**********7b /mnt/pve/hdd20t ext4 defaults,nofail 0 2
```

系统重新读取并挂载：

```sh
systemctl daemon-reload
mount -a
```

查看挂载情况：

```sh
findmnt /mnt/pve/hdd20t
```
```txt
TARGET          SOURCE    FSTYPE OPTIONS
/mnt/pve/hdd20t /dev/sda1 ext4   rw,relatime
```

```sh
df -h /mnt/pve/hdd20t
```
```txt
ilesystem      Size  Used Avail Use% Mounted on
/dev/sda1        19T  2.1M   18T   1% /mnt/pve/hdd20t
```

### 注册为 Directory 存储

```sh
pvesm add dir hdd20t --path /mnt/pve/hdd20t --content images,backup,iso,vztmpl,rootdir
```

- `images`: VM 磁盘
- `rootdir`: LXC 容器
- `backup`: 备份
- `iso`: ISO 镜像
- `vztmpl`: 容器模板

查看状态：

```sh
pvesm status
```
```txt
Name             Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
hdd20t            dir     active     19453053208            2096     18476443576    0.00%
local             dir     active        98497780        53327176        40121056   54.14%
local-lvm     lvmthin     active       794337280               0       794337280    0.00%
vmdata        lvmthin     active      3717050368       405901900      3311148467   10.92%
```

```sh
cat /etc/pve/storage.cfg
```
```txt
...
dir: hdd20t
        path /mnt/pve/hdd20t
        content iso,vztmpl,backup,rootdir,images
```

### 将这个存储加给 VM

在配置中查看槽位信息：

```sh
qm config 101
```
```
...
parent: AI122-2025-1204-0606
scsi0: vmdata:vm-101-disk-1,discard=on,iothread=1,size=2T,ssd=1
scsihw: virtio-scsi-single
smbios1: uuid=f9******-****-****-****-**********bf
sockets: 1
vmgenid: ac******-****-****-****-**********f5
```

可以看到：
- `scsi0` 是系统盘，已经在 `vmdata` 上
- `scsihw` 是 `virtio-scsi-single`
- 目前还有一个空闲的 SCSI 插槽 `scsi1`

因此可以把这个新的存储挂在 `scsi1` 上：

```sh
qm set 101 --scsi1 hdd20t:4096,format=raw,iothread=1
```

- 给 VM `101`
- 新增一块挂在 `scsi1` 的磁盘
- 存储位置在 `hdd20t`
- 大小 `4096` GiB，也就是约 4TB，可以按需调整，见下一小节
- 格式 `raw`
- 开启 `iothread=1`

```txt
update VM 101: -scsi1 hdd20t:4096,format=raw,iothread=1
Formatting '/mnt/pve/hdd20t/images/101/vm-101-disk-0.raw', fmt=raw size=4398046511104 preallocation=off
scsi1: successfully created disk 'hdd20t:101/vm-101-disk-0.raw,iothread=1,size=4T'
```

再次查看配置：

```sh
qm config 101 | grep scsi
```
```txt
...
scsi1: hdd20t:101/vm-101-disk-0.raw,iothread=1,size=4T
```

表明已经成功添加了新的磁盘。


### 优化磁盘占用

将 `ext4` 保留块比例降到 1%，提高空间利用率：

```sh
tune2fs -m 1 /dev/sda1
```
```
tune2fs 1.47.2 (1-Jan-2025)
Setting reserved blocks percentage to 1% (48829557 blocks)
```

查看当前保留块比例：

```sh
tune2fs -l /dev/sda1 | egrep 'Reserved block count|Block size'
```
```
Reserved block count:     48829557
Block size:               4096
```

查看当前磁盘使用情况：

```sh
df -h /mnt/pve/hdd20t
```
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        19T  2.1M   18T   1% /mnt/pve/hdd20t
```

预留 100GB 给宿主机和文件系统缓冲，剩下的都给 VM：

```sh
avail_gib=$(df --output=avail -BG /mnt/pve/hdd20t | tail -1 | tr -dc '0-9')
target_gib=$((avail_gib - 100))
echo "$target_gib"
```
```
18266
```

考虑到 ext4 + 标准 4KiB 块大小，单文件大小上限是 16TB。不能直接将整个 18TB 分配给 VM，否则可能会遇到下面的报错：

```txt
# qm resize 101 scsi1 ${target_gib}G
VM 101 qmp command 'block_resize' failed - Could not resize file: File too large
```

因此 VM 分配 16TB：

```sh
qm resize 101 scsi1 16380G
```

查看配置：

```sh
qm config 101 | grep scsi1
```
```
scsi1: hdd20t:101/vm-101-disk-0.raw,iothread=1,size=16380G
```

### 在 VM 中添加磁盘

上面的命令都是在 PVE 宿主机上执行的。下面的命令是在 VM 里执行的。

下面的很多命令可能似曾相识，但是需要注意区分。

上面的工作是在 PVE 中格式化 `hdd20t` 这个宿主机存储池，下面的工作是在 VM 中格式化 `scsi1` 这个虚拟磁盘。


```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
```
```
...
sda        2T disk                                              QEMU HARDDISK
├─sda1   512M part vfat     /boot/efi
└─sda2     2T part ext4     /
sdb       16T disk                                              QEMU HARDDISK
```

这里的 `sdb` 就是新加的 16TB 磁盘。


### 在 VM 中创建 GPT 分区和单一大分区

```sh
sudo parted -a optimal /dev/sdb --script mklabel gpt
sudo parted -a optimal /dev/sdb --script mkpart primary ext4 1MiB 100%
sudo partprobe /dev/sdb
```

```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT /dev/sdb
```
```
NAME   SIZE TYPE FSTYPE MOUNTPOINT
sdb     16T disk
└─sdb1  16T part
```

### 在 VM 中格式化文件系统

```sh
sudo mkfs.ext4 -L data /dev/sdb1
```

等待一会，运行完成。然后查看：

```sh
lsblk --fs /dev/sdb
```
```
NAME   FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sdb
└─sdb1 ext4   1.0   data  a6******-****-****-****-**********b2
```

### 在 VM 中挂载

```sh
sudo mkdir -p /media/data
sudo mount /dev/sdb1 /media/data
```

查看挂载情况：

```sh
df -h /media/data
```
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        16T   28K   16T   1% /media/data
```

### 设置开机自动挂载

查看 uuid：

```sh
sudo blkid /dev/sdb1
```
```
/dev/sdb1: LABEL="data" UUID="a6******-****-****-****-**********b2" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="primary" PARTUUID="fb******-****-****-****-**********1c"
```

`sudo nano /etc/fstab`，添加一行：

```sh
UUID=a6******-****-****-****-**********b2 /media/data ext4 defaults,nofail 0 2
```

挂载：

```sh
sudo mount -a
```

查看挂载情况：

```sh
df -h /media/data
```
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        16T   28K   16T   1% /media/data
```


## 七、使用自动化脚本和配置

本节记录一套可复用的自动化脚本，用来在 PVE 宿主机上创建 Ubuntu VM，并在 VM 内继续完成基础环境、Tailscale、v2ray、HDD 挂载、NVIDIA 驱动、CUDA/NVCC、zsh/tmux、`.gd.sh`、conda、Python 工具、Docker 和 NVIDIA Container Toolkit 安装。

脚本模板保存在：

```txt
docs/notes/scripts/pve-ubuntu/
├── pve_ubuntu.sh
├── pve_ubuntu.yaml
├── setup_ubuntu.sh
└── setup_ubuntu.yaml
```

`.chats/pve-ubuntu/` 中保留的是本次实际运行用的完整脚本和配置，可能包含真实密码、IP、磁盘 by-id、GPU PCI 地址等信息，并且不会随文档提交。`docs/notes/scripts/pve-ubuntu/` 中保存的是脱敏后的模板备份，用于以后在其他 PVE 宿主机或 VM 上参考和改写。

其中 `pve_ubuntu.sh` 在 PVE 宿主机上运行，负责创建 VM、准备 cloud-init、配置 GPU 直通、格式化并挂载 HDD、创建 PVE Directory Storage、给 VM 挂载 HDD-backed 数据盘。`setup_ubuntu.sh` 会被写入 VM，并在 Ubuntu 内运行，负责安装软件包、启动 SSH/Tailscale/v2ray、挂载数据盘、安装 NVIDIA 驱动和 CUDA Toolkit，并按照 `xeon` 的通用习惯生成 zsh/tmux/conda/Docker 配置。模板中不包含 `xeon` 上的私有环境变量。

v2ray 的通用安装脚本和客户端配置不在本目录重复保存，直接复用：

- `docs/notes/scripts/v2ray-install-release.sh`
- `docs/notes/configs/v2ray-client-config.json`
- 详细说明见：[安装 v2ray](./v2ray.md)

### 运行前写好的配置

运行前需要准备并修改这些文件：

- `pve_ubuntu.yaml`：PVE 宿主机侧配置，包含源宿主机、VM 参数、网络、GPU、HDD。
- `setup_ubuntu.yaml`：Ubuntu VM 内部配置，包含用户、软件包、Tailscale、v2ray、HDD、NVIDIA/CUDA、Git、dotfiles、conda、Python 工具、Docker、NVIDIA Container Toolkit。
- `pve_ubuntu.sh`：PVE 侧执行脚本。
- `setup_ubuntu.sh`：Ubuntu 侧执行脚本，会被 `pve_ubuntu.sh` 写入 cloud-init。

这些模板中的真实 IP、密码、磁盘序列、GPU PCI 地址、Git 信息都已经用占位符脱敏。`xeon`、`pve`、`qve`、`ai122`、`bj123` 只是用于区分宿主机或 VM 的标识，可以按场景保留或修改。

### 占位符说明

`pve_ubuntu.yaml` 中常见占位符：

| 占位符 | 含义 |
| --- | --- |
| `<SOURCE_PVE_LAN_IP>` | 用来复制 ISO 和 v2ray 配置的源 PVE 宿主机 LAN IP，例如 `pve` 的局域网地址。 |
| `<SOURCE_PVE_ROOT_PASSWORD>` | 源 PVE 宿主机 root 密码；脚本通过 `sshpass/scp` 复制文件。 |
| `<SOURCE_UBUNTU_ISO_PATH>` | 源 PVE 上已有的 Ubuntu ISO 路径。 |
| `<VM_ID>` | 新 VM 的 PVE ID，例如 `123`。 |
| `<VM_LAN_IP>` | 新 Ubuntu VM 的静态 LAN IP。 |
| `<LAN_GATEWAY_IP>` | 局域网网关。 |
| `<LAN_DNS_IP>` / `<PUBLIC_DNS_IP>` | DNS 服务器。 |
| `<UBUNTU_USER>` / `<UBUNTU_USER_PASSWORD>` / `<UBUNTU_FULL_NAME>` | VM 内创建的 Ubuntu 用户信息。 |
| `<GPU_PCI_ADDRESS_*>` | 要直通给 VM 的 GPU PCI 地址，例如通过 `lspci -Dnn | grep -i nvidia` 查看。 |
| `<GPU_VENDOR_DEVICE_ID>` | GPU 显卡功能的 vendor/device id，例如 `10de:2206`。 |
| `<GPU_AUDIO_VENDOR_DEVICE_ID>` | GPU HDMI/DP Audio 功能的 vendor/device id，例如 `10de:1aef`。 |
| `<GPU_PCI_ADDRESS_TO_EXCLUDE>` | 已知会导致 VM 启动失败或暂不直通的 GPU，可留作记录。 |
| `<HDD_DISK_BY_ID>` | HDD 的 `/dev/disk/by-id/` 稳定设备名，必须在目标 PVE 上重新确认。 |
| `<PVE_HDD_LABEL>` | PVE 宿主机上 HDD 分区的文件系统标签。 |
| `<PVE_HDD_MOUNTPOINT>` | PVE 宿主机上 HDD 的挂载点，例如 `/mnt/hdd-data`。 |
| `<PVE_HDD_STORAGE_NAME>` | PVE Directory Storage 名称。 |
| `<VM_DATA_DISK_SIZE_GB>` | 挂给 VM 的数据盘大小，单位是 GB，例如 `7000`。 |

`setup_ubuntu.yaml` 中常见占位符：

| 占位符 | 含义 |
| --- | --- |
| `tailscale.auth_key` | 可选 Tailscale auth key；默认留空并把 `tailscale.up` 设为 `false`，后续手动运行 `tailscale up`。 |
| `<GIT_USER_NAME>` / `<GIT_USER_EMAIL>` | VM 内 Git 全局配置。 |
| `<VM_HDD_LABEL>` | Ubuntu VM 内数据盘分区的文件系统标签。 |
| `<VM_HDD_MOUNTPOINT>` | Ubuntu VM 内数据盘挂载点，例如 `/media/data`。 |
| `dotfiles.gd_url` | `.gd.sh` 的下载地址；如果 cloud-init 已写入 `dotfiles.gd_source`，优先使用本地文件。 |
| `conda.installer_url` | Miniconda 安装脚本地址，模板默认使用 TUNA 镜像。 |
| `conda.env_name` / `conda.python_version` | 自动创建的 conda 环境名和 Python 版本。 |
| `docker.http_proxy` / `docker.https_proxy` | Docker daemon 代理。若 v2ray `new.json` 已开启 `11119`，可填 `http://127.0.0.1:11119`。 |

v2ray 配置不在这里另写一份模板。`pve_ubuntu.sh` 会从 `source.v2ray_config_dir` 复制源宿主机上的 `config.json` 和 `new.json`，再通过 cloud-init 写入 VM；如果需要从头生成客户端配置，参考 [安装 v2ray](./v2ray.md) 和 `docs/notes/configs/v2ray-client-config.json`。

### 阶段开关

两份 YAML 都支持阶段开关：

```yaml
global:
  mode: auto

stages:
  gpu_passthrough:
    mode: auto
```

可选值：

- `auto`：自动运行该阶段。
- `manual` 或 `skip`：跳过该阶段。
- `confirm`：运行时询问是否执行。

如果某个阶段已经完成，可以把它改成 `skip`。如果只想补跑某一阶段，可以把其他阶段设为 `skip`，目标阶段设为 `auto`。

PVE 侧主要阶段：

```txt
install_host_packages
copy_iso
copy_v2ray_config
create_vm
hdd_storage
attach_hdd
gpu_passthrough
start_vm
```

Ubuntu 侧主要阶段：

```txt
apt_sources
base_packages
qemu_guest_agent
ssh
tailscale
v2ray
hdd_mount
nvidia_driver
cuda
git
dotfiles
conda
python_tools
docker
nvidia_container
zsh
desktop
```

其中 NVIDIA 相关阶段的职责边界如下：

- `nvidia_driver`：只安装 Ubuntu VM 内核态 NVIDIA 驱动，目标是让 `nvidia-smi` 正常。
- `cuda`：只安装 CUDA Toolkit / `nvcc`，不负责 Docker runtime。
- `docker`：只安装 Docker Engine、Compose、registry mirror、daemon 代理和用户组。
- `nvidia_container`：只在 Docker 和 `nvidia-smi` 都正常后，安装 NVIDIA Container Toolkit，并通过 `nvidia-ctk runtime configure --runtime=docker` 合并更新 Docker runtime。

### 在 PVE 宿主机上运行

先把模板复制到目标 PVE 宿主机，例如 `qve`：

```sh
scp -r docs/notes/scripts/pve-ubuntu root@qve:/root/pve-ubuntu
scp docs/notes/scripts/v2ray-install-release.sh root@qve:/root/pve-ubuntu/
```

登录目标 PVE：

```sh
ssh root@qve
cd /root/pve-ubuntu
```

按目标机器修改配置：

```sh
nano pve_ubuntu.yaml
nano setup_ubuntu.yaml
chmod +x v2ray-install-release.sh
```

至少需要确认：

- `source.ip`、`source.password`、`source.iso_path`
- `vm.id`、`vm.name`、`vm.hostname`
- `vm.vga`，纯 SSH/算力卡场景可设为 `none`
- `network.ipv4`、`network.gateway4`、`network.dns`
- `ubuntu.user`、`ubuntu.password`
- `gpu_passthrough.pci_addresses`、`gpu_passthrough.vfio_ids`
- `hdd.disk_by_id`、`hdd.partition`
- `hdd.wipe_existing`
- `hdd.vm_disk.size`
- `source.v2ray_config_dir`，以及源宿主机中是否存在 `config.json` 和 `new.json`

如果某张 GPU 是宿主机的 boot VGA，但仍希望作为 VM 的算力卡直通，可以先确认：

```sh
cat /sys/bus/pci/devices/<GPU_PCI_ADDRESS>.0/boot_vga
```

值为 `1` 表示它是宿主机启动显卡。纯计算用途下，可以在 `gpu_passthrough.pci_addresses` 中给这张卡加 `rombar=0`，并把 `vm.vga` 设为 `none`：

```yaml
vm:
  vga: none

gpu_passthrough:
  pci_addresses:
    - "0000:02:00"
    - "0000:03:00"
    - "0000:04:00,rombar=0"
```

这会让 PVE 的图形 Console 预期不可用或黑屏，但 SSH、guest agent、NVIDIA/CUDA 计算不受影响。

::: warning
`hdd.wipe_existing: true` 会格式化目标 HDD。换机器前必须用下面命令确认设备确实是要清空的数据盘：

```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL
ls -l /dev/disk/by-id/
```
:::

运行 PVE 侧脚本：

```sh
bash pve_ubuntu.sh pve_ubuntu.yaml
```

如果脚本配置了 GPU 直通并提示需要重启，执行：

```sh
reboot
```

宿主机重新上线后再次运行同一命令。已经完成的阶段会按配置和现有状态跳过。

```sh
cd /root/pve-ubuntu
bash pve_ubuntu.sh pve_ubuntu.yaml
```

### 在 Ubuntu VM 内运行或补跑

正常情况下，`setup_ubuntu.sh` 和 `setup_ubuntu.yaml` 会通过 cloud-init 写入 VM 的 `/opt/bj123-setup/`，并在首次启动时自动运行。

如果需要手动补跑：

```sh
ssh <UBUNTU_USER>@<VM_LAN_IP>
sudo bash /opt/bj123-setup/setup_ubuntu.sh /opt/bj123-setup/setup_ubuntu.yaml
```

如果没有配置 Tailscale auth key，手动运行：

```sh
sudo tailscale up --hostname=bj123
```

命令会输出一个授权链接。复制链接到浏览器中确认授权后，VM 会加入 tailnet。

### Ubuntu 22.04 Kernel 版本

Ubuntu 22.04.5 LTS 可能运行 GA kernel `5.15`，也可能运行 HWE kernel `6.8`。这不是 `/etc/os-release` 里的 Ubuntu 发行版号，而是内核分支差异。

对纯 SSH 和算力卡 VM，只要下面内容正常，就不需要为了和其他机器一致而升级 kernel：

- `nvidia-smi` 能看到全部 GPU。
- `nvcc --version` 正常。
- `nvidia-container-cli info` 正常。
- SSH、Tailscale、qemu guest agent、Docker 正常。

升级到 HWE kernel 会触发 NVIDIA DKMS 重新构建并需要重启，反而会增加变量。只有在明确需要新内核功能或当前驱动/硬件存在内核相关问题时，再考虑升级。

### 运行后自动生成的内容

PVE 宿主机上会生成或修改：

- `/root/pve-ubuntu/`：运行目录，包含脚本、配置、复制来的 ISO 和 v2ray 配置。
- `/root/pve-ubuntu/seed/`：cloud-init 的 `user-data`、`meta-data`、`network-config`。
- `/var/lib/vz/template/iso/<vm>-cidata.iso`：cloud-init seed ISO。
- `/etc/default/grub` 或 `/etc/kernel/cmdline`：IOMMU/VFIO 内核参数。
- `/etc/modules-load.d/vfio.conf`
- `/etc/modprobe.d/vfio.conf`
- `/etc/modprobe.d/blacklist-nvidia-passthrough.conf`
- `/etc/fstab`：HDD 自动挂载。
- PVE storage：例如 `<PVE_HDD_STORAGE_NAME>`。
- VM 配置：`scsi0` 系统盘、`scsi1` HDD-backed 数据盘、`hostpci*` GPU 直通、`efidisk0`。

Ubuntu VM 内会生成或修改：

- `/opt/bj123-setup/`：VM 内脚本和配置。
- `/var/log/setup_ubuntu.log`
- `/usr/local/etc/v2ray/config.json`
- `/usr/local/etc/v2ray/new.json`
- `v2ray.service`
- `v2ray@new.service`
- `/etc/fstab`：数据盘自动挂载。
- `<VM_HDD_MOUNTPOINT>`：数据盘挂载点。
- `/etc/profile.d/cuda.sh`
- `/usr/local/cuda`
- `~/.zshrc`、`~/.zshenv`：zsh prompt、常用 alias、`.gd.sh`、conda、CUDA、Hugging Face mirror、数据盘环境变量。
- `~/.tmux.conf`：以 `xeon` 通用配置为参考的 tmux 配置和插件入口。
- `~/.gd.sh`
- `~/.pip/pip.conf`
- `~/.condarc`
- `~/miniconda3/` 和 conda env，例如 `ai`。
- `/etc/docker/daemon.json`
- `/etc/systemd/system/docker.service.d/proxy.conf`
- `/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg`
- `/etc/apt/sources.list.d/nvidia-container-toolkit.list`
- Tailscale 状态和主机名。

### 验证命令

PVE 宿主机上检查：

```sh
cat /proc/cmdline
dmesg | grep -m1 -E "DMAR: IOMMU enabled|IOMMU enabled"
lspci -Dnnk | awk '/NVIDIA/{print; n=1; next} n && /Kernel driver in use/{print; n=0}'
qm config <VM_ID>
pvesm status
findmnt <PVE_HDD_MOUNTPOINT>
```

Ubuntu VM 内检查：

```sh
hostname
tailscale ip -4
systemctl is-active qemu-guest-agent ssh tailscaled v2ray v2ray@new
ss -ltnp | grep -E ":1111(0|1|8|9)"
findmnt <VM_HDD_MOUNTPOINT>
df -h <VM_HDD_MOUNTPOINT>
nvidia-smi
nvcc --version
nvidia-container-cli info
docker info | grep -i runtime
zsh -ic 'echo $CONDA_DEFAULT_ENV; python --version; command -v gd gpustat pipreqs'
mokutil --sb-state
```

### 样例脚本和配置

<details> <summary><code>pve_ubuntu.sh</code></summary>

<<< @/notes/scripts/pve-ubuntu/pve_ubuntu.sh

</details>

<details> <summary><code>pve_ubuntu.yaml</code></summary>

<<< @/notes/scripts/pve-ubuntu/pve_ubuntu.yaml

</details>

<details> <summary><code>setup_ubuntu.sh</code></summary>

<<< @/notes/scripts/pve-ubuntu/setup_ubuntu.sh

</details>

<details> <summary><code>setup_ubuntu.yaml</code></summary>

<<< @/notes/scripts/pve-ubuntu/setup_ubuntu.yaml

</details>
