# PVE 创建 Windows 10 虚拟机

## 一、创建和下载镜像

### 创建 Windows 10 镜像

访问页面：Download Windows 10
- https://www.microsoft.com/en-us/software-download/windows10

"Create Windows 10 installation media" > 点击 `Download Now` 下载工具：
- https://go.microsoft.com/fwlink/?LinkId=2265055
- 选择 创建 ISO 镜像文件
- 选择 语言、版本、体系结构（64 位），并命名
- 等待镜像制作完成

### 下载 VirtIO 驱动 ISO

访问页面：Windows VirtIO Drivers - Proxmox VE
- https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers#Installation

下载稳定版：
- https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

## 二、上传 ISO 到 PVE 服务器

访问 PVE 管理页面：
- 在左侧树状文件结构中，选择 `local (pve)`，点击选项卡中的 "ISO Images"
- 点击 `Upload`，上传制作好的 Windows 10 ISO 和 下载好的 VirtIO ISO
- iso 文件默认存储在：`/var/lib/vz/template/iso`
- 如果不方便直接上传，也可以在其他服务器上，通过 rsync 将 ISO 文件复制到该目录下：

  ```sh
  rsync -avhP <username>@<server>:/path/to/virtio-win-0.1.285.iso /var/lib/vz/template/iso/
  rsync -avhP <username>@<server>:/path/to/Windows10-Chinese-64bit.iso /var/lib/vz/template/iso/
  ```

## 三、创建 Windows 10 虚拟机

节点名 pve，磁盘存储用 vmdata。

### 3.1 启动“创建虚拟机”向导

1. 在左侧树中选中节点 `pve`
2. 上边工具栏点击 `Create VM`

#### General 选项卡

* `Node`：`pve`（默认就是）
* `VM ID`：默认即可（比如 301），也可以自己指定
* `Name`：比如 `win10`

点击 Next。

### 3.2 OS 选项卡：选择 Windows ISO + VirtIO ISO

1. ISO image
   * 选择 `Use CD/DVD disc image file (iso)`
   * Storage：选择 `local (pve)`
   * ISO image：选中刚上传的 Windows 10 ISO

2. Guest OS
   * Type：`Microsoft Windows`
   * Version：选 `11/2022/2025`

3. Add additional drive for VirtIO drivers（PVE 9 向导里的新选项）
   * 勾选 `Add additional drive for VirtIO drivers`
   * 在出现的下拉框里，选择刚刚上传的 `virtio-win.iso`
   * 这样系统会自动给 VM 加一个第二光驱，挂载 VirtIO 驱动盘（比之后手动加 CD 好用很多）

点击 Next。

### 3.3 System 选项卡：固件、控制器 和 QEMU Agent

这里按 Proxmox 官方的 Windows 10 最佳实践设置。

1. Graphic card：`Default` 或 `SPICE` 均可，先用 Default 就行
2. Machine：`q35`（推荐，较新的虚拟硬件平台）
3. BIOS/Firmware：
   * 建议选 `OVMF (UEFI)`
   * 勾选 `Add EFI Disk`：
     * EFI Storage：选 `vmdata`
4. SCSI Controller：选择 `VirtIO SCSI Single`（性能好，官方推荐）
6. Qemu Agent：勾选（推荐），后面我们在 Windows 里安装 Guest Tools 来配合使用
7. 取消勾选 `Add TPM`：
   * 如果计划在里面开启 VBS/BitLocker 等安全特性，可以勾选 Add TPM，TPM Storage 选 `vmdata`

点击 Next。

### 3.4 Disks 选项卡：把系统盘建在 vmdata 上

1. Bus/Device：选 `SCSI`
2. Storage：选择 `vmdata`（你的 LVM-Thinpool）
3. Disk size (GiB)：根据需要，比如 200 ~ 500 GiB
4. Cache：
   * 更稳妥：保持默认 `Default (No cache)`
   * 追求性能：可选 `Write back`（性能好，但断电时略有数据风险）
5. Discard：勾选（启用 TRIM，配合 LVM-Thin 节省空间）。
6. IO thread：勾上（单独 IO 线程，磁盘性能更好）

点击 Next。

### 3.5 CPU 选项卡

1. Sockets：1（一般够用）
2. Cores：设为 `16`
3. Type：
   * 单主机不迁移 VM：可以选 `host`，性能最好
   * 要考虑迁移 / 集群兼容性：用默认 `x86-64-v2` 或 Proxmox 推荐的通用 CPU 型号
4. Extra CPU Flags：（点开 Advanced）
   * 如果要用到嵌套虚拟化（在 Win10 里再跑虚拟机）或 VBS，可以考虑打开相关虚拟化扩展（PVE 9.1 新增更精细控制）

点击 Next。

### 3.6 Memory 选项卡

1. Memory (MiB)：
   * 常用值：`4096`（4GB），`8192`（8GB），`16384`（16GB），`32768`（32GB），`65536`（64GB）
2. Ballooning Device：
   * 如果在 PVE 上跑很多 VM，可以勾选
   * 如果主机内存足够，不在乎动态调整，可以不勾

点击 Next。

### 3.7 Network 选项卡

1. Bridge：默认是 `vmbr0`（主网桥）
2. Model：`VirtIO (paravirtualized)`（性能最好，但需要 VirtIO 网卡驱动）
3. Firewall：默认启用（开启后可用 Proxmox 自带防火墙）

点击 Next，到 Confirm，确认无误，点击 Finish 完成创建。

此时的状态是：

* 系统盘在 vmdata (LVM-Thin)
* 有两个虚拟光驱（一个挂 Windows 10 ISO，一个挂 virtio-win.iso）
* 使用 VirtIO SCSI + VirtIO 网卡 的 Windows 10 VM

---

## 四、在 VM 中安装 Windows 10：加载 VirtIO 磁盘驱动

### 4.1 通过控制台启动 VM

1. 在左侧树中点击刚创建的 VM `301 (Win10)`
2. 切到 Console 选项卡
3. 点右上角 `Start` 启动，如果 Console 无法显示，就再点一次，试试 noVNC
4. 在黑屏上出现 `Press any key to enter the Boot Manager Menu` 时按任意键，从 Windows 安装 ISO 启动
5. 此时界面中会出现下面的选项：

   ```sh{3}
   UEFI QEMU QEMU HARDDISK
   UEFI QEMU DVD-ROM QM00003
   UEFI QEMU DVD-ROM QM00001
   UEFI PXEv4 (MAC:BC241160462A)
   UEFI PXEv6 (MAC:BC241160462A)
   UEFI HTTPv4 (MAC:BC241160462A)
   UEFI HTTPv6 (MAC:BC241160462A)
   EFI Firmware Setup
   ```

  * 先试试选择 `UEFI QEMU DVD-ROM QM00001`，在 PVE 里，第一个光驱（QM00001）通常挂的是 Windows 10 安装 ISO
  * 如果选择 `QM00001` 之后，看到 `Press any key to boot from CD or DVD…` 或立刻进入 Windows 安装向导，就说明对了
  * 如果选了 `QM00001` 进去以后，直接报错/黑屏/又回到这个菜单，说明这个盘可能是 VirtIO 驱动盘
  * 如果没有自动跳回菜单，关机或重启 VM，再进一次 Boot Manager
  * 改选 `UEFI QEMU DVD-ROM QM00003`，这个应该就是 Windows 安装 ISO

6. 等 Windows 安装完成之后，以后正常开机就不用再进这个菜单了
  * 让 VM 直接从 `UEFI QEMU QEMU HARDDISK` 启动
  * 或者在 PVE 的 VM → Options → Boot Order 里把硬盘设为第一启动项

7. 接下来就是 Windows 安装界面（选择语言、时间、键盘布局等），点击 `现在安装` 即可。
   * 选择 `我没有产品密钥`
   * 选择 `Windows 10 专业版`
   * 选择 `自定义：仅安装 Windows（高级）`

### 4.2 到“选择安装位置”时加载 VirtIO 磁盘驱动

1. 此时应该会出现 `你想将 Windows 安装在哪里？`，但是列表里没有任何磁盘
   * 别急，因为系统盘用了 VirtIO SCSI，Windows 原生不带这种驱动，需手动加载
2. 点击底部的 `加载驱动程序`
3. 在弹出窗口点击 `浏览`
4. 选择 CD 驱动器 `virtio-win-0.1.285.iso`，找到对应驱动所在目录：
   * `vioscsi` → `w10` → `amd64`
   * 选择 `amd64` 文件夹，点击确定
5. 安装程序会列出类似：
   * `Red Hat VirtIO SCSI pass-through controller (D:\vioscsi\w10\amd64\vioscsi.inf)`
   * 选择它，点击下一页，等待驱动加载完成
6. 加载完成后，会自动回到磁盘列表，这时就能看到在 vmdata 上创建的虚拟磁盘了，并且空间大小正确

### 4.3 分区并完成 Windows 10 安装

1. 选中刚出现的磁盘
2. 点击下一页，让 Windows 自动分区（或者点击“新建”手动分区）
3. 之后就是正常的拷贝文件、重启等流程，按提示设置：
   * 地区、键盘布局等
   * 选择 `我没有 Internet 连接`，后面装好 VirtIO 驱动后再联网
   * 选择 `继续执行有限设置`
   * 账户、密码等
   * 关闭所有隐私选项

安装结束后，就可以登录到 Windows 10 桌面了。

## 五、在 Windows 里安装 VirtIO 全套驱动 + Guest Tools

此时系统盘和基本显卡驱动已 OK，但：

* 网卡不可用，或者设备管理器里是未知设备
* QEMU Guest Agent 也未安装

用 virtio-win 光盘里的安装包一键装好：

1. 登录 Windows 10 后，打开“此电脑”
2. 可以看到挂载的 VirtIO 驱动光盘，`CD 驱动器(D:) virtio-win-0.1.285`
3. 进入该光盘，点击运行 `virtio-win-gt-x64.msi`（有的版本叫 `virtio-win-guest-tools.exe`）
4. 按照向导一路 Next：
   * 会安装存储、网卡、balloon、串口等驱动
   * 会一并安装 QEMU Guest Agent
5. 安装完成后重启 Windows
6. 重启后在设备管理器中检查：
   * 不应再有带感叹号的未知设备
   * `网络适配器` 下应出现 `Red Hat VirtIO Ethernet Adapter` 之类设备
7. 此时网络应该已经通了，可以上网或访问局域网
8. 如果在 System 里勾选了 `Qemu Agent`，且 Windows 里也装好了 Guest Tools：
   * 在 Proxmox Web UI 的 VM 概览页面会自动显示 Guest IP
   * 关机/重启会触发正常的系统关机命令等

## 六、Windows 中的一些个性化配置

* `远程桌面设置`：将 `启用远程桌面` 打开
* `电源和睡眠`：将 `在接通电源的情况下，经过以下时间后关闭` 设为 `从不`
* `更改用户账户控制设置`：将滑块调到最底部 `从不通知`
* 参考：[安装V2ray](./v2ray.md#windows-安装-v2ray)
* 参考：[激活 Windows](./windows-activate.md)

## 附1：Proxmox 侧的一些推荐优化（可选）

这些不是必须，但比较实用：

1. 确认磁盘 Discard 生效
   * VM 硬件里磁盘勾了 Discard
   * Windows 10 默认就支持 TRIM，不用额外操作
   * 可以在命令行 `fsutil behavior query DisableDeleteNotify` 查看是否启用
2. 备份策略
   * 在 Datacenter → Backup 里给 Windows VM 做定期备份
   * 建议到另一块存储，不要和 vmdata 放一起
3. 关机 / 重启方式
   * 装好 Guest Agent 后，用 Proxmox 里 VM 的菜单 `Shutdown` 比直接强制 `Stop` 更安全
4. 显卡/分辨率体验
   * 如果用的是 SPICE 显示，可以在 Windows 里安装 `spice-guest-tools`（VirtIO ISO 一般附带）使用剪贴板共享

## 附2：命令行创建：一些常用的 qm 命令

上面的都是在 Web 界面创建和配置 VM 的。其实也可以用 qm 命令行工具来创建。一些命令示例：

```sh
# 创建空 VM
qm create 100 --name Win10 --memory 4096 --cores 4 --sockets 1 --net0 virtio,bridge=vmbr0 --machine q35 --bios ovmf

# 添加 EFI 磁盘
qm set 100 --efidisk0 vmdata:1

# 添加系统盘（在 vmdata 上）
qm set 100 --scsihw virtio-scsi-single --scsi0 vmdata:32

# 挂载 Windows 10 ISO 和 VirtIO ISO
qm set 100 --ide2 local:iso/Win10_22H2_x64.iso,media=cdrom
qm set 100 --ide3 local:iso/virtio-win.iso,media=cdrom

# 启用 QEMU Agent
qm set 100 --agent enabled=1
```

之后再在 Web 界面或 `qm start 100` 启动安装即可。

此时，状态是：

* 在 `vmdata (LVM-Thinpool)` 上创建好了一个 Windows 10 虚拟机系统盘
* 使用官方推荐的 q35 + UEFI + VirtIO SCSI + VirtIO 网卡 + QEMU Agent 组合
* 安装好了 VirtIO 驱动和 Guest Tools，性能和管理体验都比较理想


