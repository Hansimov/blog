# Ubuntu 配置 Intel P3608

## 速览

- 系统里原本已有两块致态 NVMe，不应与 Intel 卡混淆：
  - `/dev/nvme1n1`: `ZHITAI TiPlus7100s 4TB`
  - `/dev/nvme3n1`: `ZHITAI Ti600 4TB`
- 新插入的 Intel 卡在 Linux 里被识别为两个独立的 NVMe 逻辑设备，而不是一个盘上的两个分区：
  - `/dev/nvme0n1`: `INTEL SSDPECME040T4`, SN=`<P3608_CTRL_A_SN>`
  - `/dev/nvme2n1`: `INTEL SSDPECME040T4`, SN=`<P3608_CTRL_B_SN>`
- 初始状态下，两个 Intel 逻辑设备都只暴露出约 `1.00 TB` 容量，合计约 `2 TB`。
- 现已在当前 Ubuntu 上恢复成功：
  - `/dev/nvme0n1`: `2.00 TB / 2.00 TB`
  - `/dev/nvme2n1`: `2.00 TB / 2.00 TB`
  - 整卡总可见容量恢复到约 `4 TB`
- 当前已经按两个独立文件系统使用：
  - `/media/p3608a`
  - `/media/p3608b`

## 为什么会出现两个 Intel 设备

这不是“一个硬盘被识别成两个分区”，而是 Linux 看到了一张 Intel AIC 卡上的两个独立 NVMe 控制器/端点。

关键证据如下。

### 1. `nvme list-subsys` 显示为两个独立子系统

```bash
nvme list-subsys
```

观察到：

```text
nvme-subsys0 ...
 +- nvme0 pcie 0000:e4:00.0 live

nvme-subsys2 ...
 +- nvme2 pcie 0000:e5:00.0 live
```

### 2. `lspci` 显示两个独立 PCIe NVMe 端点

```bash
lspci -nn -s e4:00.0
lspci -nn -s e5:00.0
```

输出核心信息：

```text
e4:00.0 Non-Volatile memory controller [0108]: Intel Corporation PCIe Data Center SSD [8086:0953]
e5:00.0 Non-Volatile memory controller [0108]: Intel Corporation PCIe Data Center SSD [8086:0953]
```

### 3. 两个控制器各自有独立序列号

```bash
cat /sys/block/nvme0n1/device/serial
cat /sys/block/nvme2n1/device/serial
```

结果分别为两个不同的序列号：

```text
<P3608_CTRL_A_SN>
<P3608_CTRL_B_SN>
```

### 4. 控制器能力表明它们各自都是单控制器、单 namespace

```bash
sudo nvme id-ctrl -H /dev/nvme0
sudo nvme id-ctrl -H /dev/nvme2
```

关键字段：

```text
cmic      : 0
	Single Controller
	Single Port

oacs      : 0x6
	Format NVM Supported
	NS Management and Attachment Not Supported

nn        : 1
```

这说明：

- 每个 Intel 端点自己就是一个单独控制器
- 每个控制器最多只有 `1` 个 namespace
- 这张卡当前不支持标准 NVMe namespace 的创建、删除、扩容操作

## 初始排查结果

### 查看块设备

```bash
lsblk -d -o NAME,MODEL,SIZE,ROTA,TYPE,SERIAL,TRAN
```

初始排查时，与本次相关的结果：

```text
nvme3n1 ZHITAI Ti600 4TB         3.6T
nvme1n1 ZHITAI TiPlus7100s 4TB   3.7T
nvme0n1 INTEL SSDPECME040T4    931.5G
nvme2n1 INTEL SSDPECME040T4    931.5G
```

### 查看 NVMe 层识别结果

```bash
sudo nvme list
```

初始状态下，与 Intel 卡相关的输出：

```text
/dev/nvme0n1  INTEL SSDPECME040T4  1.00 TB / 1.00 TB
/dev/nvme2n1  INTEL SSDPECME040T4  1.00 TB / 1.00 TB
```

### 清理旧数据和旧分区后，容量仍然没有恢复

下面这些步骤已经实际执行过：

```bash
sudo nvme format /dev/nvme0n1 --lbaf=0 --ses=1 --force
sudo nvme format /dev/nvme2n1 --lbaf=0 --ses=1 --force

sudo sgdisk --zap-all /dev/nvme0n1
sudo sgdisk --zap-all /dev/nvme2n1
sudo wipefs -a /dev/nvme0n1 /dev/nvme2n1

sudo parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart primary 1MiB 100%
sudo parted -s -a optimal /dev/nvme2n1 mklabel gpt mkpart primary 1MiB 100%
```

结论：

- 这些步骤可以安全清理旧数据、旧 GPT 和旧签名
- 但不能把容量从 `1 TB + 1 TB` 恢复到 `2 TB + 2 TB`
- 也就是说，问题不在分区层，而在控制器层的可见容量配置

## 实际成功恢复容量的流程

### 1. 安装官方 Solidigm Linux CLI

后续在 Solidigm 官方支持页 `ka-00085` 找到了当前可下载的 `Solidigm Storage Tool`，当前机器实际使用的是 Linux `deb` 包：

- https://www.solidigm.com/support-page/drivers-downloads/ka-00085.html
- https://sdmsdfwdriver.blob.core.windows.net/files/kba-gcc/drivers-downloads/ka-00085/sst--2-7/sst-cli-linux-deb--2-7.zip

```bash
sudo dpkg -i sst_2.7.337-0_amd64.deb
sudo sst version
```

确认版本为：

```text
Solidigm(TM) Storage Tool
Version: 2.7.337
```

### 2. 用 `sst` 读取控制器当前状态

实际使用的读取命令：

```bash
sudo sst show -ssd
sudo sst show -a -ssd <P3608_CTRL_A_SN>
sudo sst show -a -ssd <P3608_CTRL_B_SN>
```

关键结果如下：

- 两个控制器都被识别为 `Intel SSD DC P3608 Series`
- 两个控制器在恢复前都满足：
  - `MaximumLBA : 1953514583`
  - `NativeMaxLBA : 3907029167`
  - `PercentOverProvisioned : 50.000000`

这一步把问题坐实为：

- 不是 GPT、分区或文件系统问题
- 而是两个控制器都被压成了 `50%` 可见容量

### 3. 执行容量恢复

先对两个控制器执行 `delete`：

```bash
sudo sst delete -force -ssd <P3608_CTRL_A_SN>
sudo sst delete -force -ssd <P3608_CTRL_B_SN>
```

实际返回均为：

```text
Status : Delete successful.
```

随后执行：

```bash
sudo sst set -ssd <P3608_CTRL_A_SN> MaximumLBA=native
sudo sst set -ssd <P3608_CTRL_B_SN> MaximumLBA=native
```

这里 CLI 返回的是：

```text
No results
```

但继续用 `show -a -ssd` 复查后，设备状态已经变为：

- `MaximumLBA : 3907029167`
- `NativeMaxLBA : 3907029167`
- `PercentOverProvisioned : 0.000000`

结论：

- 容量恢复已经生效
- 这里要以 `show` 的结果为准，而不是只看 `set` 那一行文本输出

### 4. 让 Linux 重新识别新的 `2 TB + 2 TB`

厂商工具层已经恢复后，还需要让 Linux 重新读取控制器状态：

```bash
sudo nvme reset /dev/nvme0
sudo nvme reset /dev/nvme2
sudo partprobe /dev/nvme0n1
sudo partprobe /dev/nvme2n1
sudo udevadm settle
```

验证结果：

```bash
sudo nvme list
```

当前已经变成：

```text
/dev/nvme0n1  INTEL SSDPECME040T4  2.00 TB / 2.00 TB
/dev/nvme2n1  INTEL SSDPECME040T4  2.00 TB / 2.00 TB
```

## 当前落地方式：按两个约 `2 TB` 的盘使用

### 1. 重新分区并格式化

实际执行命令如下：

```bash
sudo wipefs -a /dev/nvme0n1 /dev/nvme2n1

sudo sgdisk --zap-all /dev/nvme0n1
sudo sgdisk --zap-all /dev/nvme2n1

sudo parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart primary 1MiB 100%
sudo parted -s -a optimal /dev/nvme2n1 mklabel gpt mkpart primary 1MiB 100%

sudo mkfs.ext4 -F -m 0 -L p3608a /dev/nvme0n1p1
sudo mkfs.ext4 -F -m 0 -L p3608b /dev/nvme2n1p1
```

### 2. 挂载到 `/media/p3608a` 和 `/media/p3608b`

```bash
sudo mkdir -p /media/p3608a /media/p3608b
sudo mount /dev/nvme0n1p1 /media/p3608a
sudo mount /dev/nvme2n1p1 /media/p3608b
```

当前结果：

- `/media/p3608a` -> `/dev/nvme0n1p1`
  - `LABEL="p3608a"`
  - `UUID="<P3608A_UUID>"`
- `/media/p3608b` -> `/dev/nvme2n1p1`
  - `LABEL="p3608b"`
  - `UUID="<P3608B_UUID>"`

### 3. `/etc/fstab` 当前写法

本机当前长期挂载条目为：

```fstab
UUID=<P3608A_UUID> /media/p3608a ext4 defaults,noatime,nofail 0 2
UUID=<P3608B_UUID> /media/p3608b ext4 defaults,noatime,nofail 0 2
```

验证挂载点：

```bash
sudo findmnt -T /media/p3608a
sudo findmnt -T /media/p3608b
```

## 实际踩过的坑

### 1. 只用 `nvme-cli` 清数据和重建 GPT，不能恢复容量

已经验证：

- `nvme format --ses=1`
- `sgdisk --zap-all`
- `wipefs -a`
- `parted mklabel gpt mkpart`

这些都只能完成清理和重分区，不能把 `MaximumLBA` 改回去。

### 2. `sst set ... MaximumLBA=native` 返回 `No results`，但不代表失败

这是本次最容易误判的一点。

实际现象是：

- `set` 命令行输出为 `No results`
- 但 `show -a -ssd` 再读一次后，`MaximumLBA` 已经等于 `NativeMaxLBA`
- `PercentOverProvisioned` 也已经从 `50%` 变成 `0%`

因此必须复查设备属性，不能只看那一行返回文本。

### 3. 厂商工具恢复后，Linux 块设备层不会立刻同步

本次实际现象是：

- `sst show` 已经显示每个控制器 `2.00 TB`
- `nvme list` 更新后，`lsblk` 仍可能暂时保留旧的块设备视图

解决方式就是：

```bash
sudo nvme reset /dev/nvme0
sudo nvme reset /dev/nvme2
sudo partprobe /dev/nvme0n1
sudo partprobe /dev/nvme2n1
sudo udevadm settle
```

### 4. 不要在未安装的情况下直接从解压目录裸跑 `sst`

本次试过直接解压 `deb` 包后运行二进制，结果遇到库加载问题。最终稳定方案是：

```bash
sudo dpkg -i sst_2.7.337-0_amd64.deb
```

也就是直接安装官方包，而不是在临时目录里手工拼运行环境。

### 5. 恢复容量后，旧分区节点可能和新容量不一致

恢复前如果已经存在旧的 `p1` 分区节点，容量变化后需要重新：

- 清签名
- `zap-all`
- 重建 GPT
- 重新创建整盘分区

不要直接沿用恢复前那套旧分区。

### 6. 注意 nvme 编号

由于这张卡的两个控制器被识别为两个独立设备，所以它们在 Linux 里分别是 `nvme0` 和 `nvme2` 。

当然，不同的系统环境和不同的插槽位置可能会导致编号不一样，需要根据实际情况调整命令中的设备名称。

## 当前最终状态

### 当前容量状态

```bash
sudo nvme list
```

当前与 P3608 相关的结果：

```text
/dev/nvme0n1  INTEL SSDPECME040T4  2.00 TB / 2.00 TB
/dev/nvme2n1  INTEL SSDPECME040T4  2.00 TB / 2.00 TB
```

### 当前挂载状态

```bash
sudo findmnt -T /media/p3608a
sudo findmnt -T /media/p3608b
```

当前结果应指向：

- `/media/p3608a` -> `/dev/nvme0n1p1`
- `/media/p3608b` -> `/dev/nvme2n1p1`
