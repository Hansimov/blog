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

### 安装 NVDIA 驱动和 NVCC+CUDA

参考：[Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)](./nvidia-driver.md)

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

## 五、把 20TB HDD 配置成大容量数据存储并挂给 VM（可选，但符合你需求）

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
