# Ubuntu 安装新硬盘

::: tip See: InstallingANewHardDrive - Community Help Wiki
* https://help.ubuntu.com/community/InstallingANewHardDrive
:::

## 查看硬盘信息

```sh
sudo lshw -C disk
```

输出内容形如：

```sh{4,8,13,23,33}
  *-namespace:0
       description: NVMe disk
       physical id: 0
       logical name: hwmon3
  *-namespace:1
       description: NVMe disk
       physical id: 2
       logical name: /dev/ng0n1
  *-namespace:2
       description: NVMe disk
       physical id: 1
       bus info: nvme@0:1
       logical name: /dev/nvme0n1
       size: 476GiB (512GB)
       capabilities: gpt-1.00 partitioned partitioned:gpt
       configuration: guid=********-****-****-****-************ logicalsectorsize=512 sectorsize=512 wwid=eui.00000000000000******************
  *-disk:0
       description: SCSI Disk
       product: 001-1ER164
       vendor: ST2000DM
       physical id: 0.0.0
       bus info: scsi@0:0.0.0
       logical name: /dev/sda
       version: 0015
       serial: 670200213C04
       size: 1863GiB (2TB)
       capabilities: gpt-1.00 partitioned partitioned:gpt
       configuration: ansiversion=6 guid=*******-****-****-****-*********** logicalsectorsize=512 sectorsize=512
  *-disk:1
       ...
       physical id: 0.0.1
       bus info: scsi@0:0.0.1
       logical name: /dev/sdb
       ...
       size: 1863GiB (2TB)
       ...
```

这意味着机器上目前插了 3 块盘：
- 1 * NVMe disk（`/dev/nvme0n1`）
- 2 * SCSI Disk（`/dev/sda` 和 `/dev/sdb`）。

重点关注 `*-disk` 的 `logical name`（也即 `/dev/sda` 和 `/dev/sdb`），后面会用到。


当然也可以用 `fdisk` 查看更详细的信息：

```sh
sudo fdisk -l
```

## 硬盘分区

如果硬盘已经格式化过并且包含数据，可以选择跳过该部分。

如果硬盘空白且未格式化，那么可以选择命令行工具或者图形界面（GParted）进行格式化。

本文选择命令行工具<f>（parted）</f>格式化。fdisk 比较老了，主要缺点是只能创建 MBR 分区。

### GPT vs MBR

MBR<f>（Master Boot Record）</f>有两个主要限制：分区不能大于 2 TB，主分区不能超过 4 个。

GPT<f>（GUID Partition Table）</f>没有这两个限制，但需要内核支持 EFI，一般新的发行版都是支持的。

### 使用 parted 进行分区

这里以 `/dev/sda` 为例，进行分区：

```sh
sudo parted /dev/sda
```

进入分区界面。键入 `help` 查看帮助：

```sh
(parted) help
  align-check TYPE N                       check partition N for TYPE(min|opt) alignment
  help [COMMAND]                           print general help, or help on COMMAND
  mklabel,mktable LABEL-TYPE               create a new disklabel (partition table)
  mkpart PART-TYPE [FS-TYPE] START END     make a partition
  name NUMBER NAME                         name partition NUMBER as NAME
  print [devices|free|list,all|NUMBER]     display the partition table, available devices, free space, all found partitions, or a particular partition
  quit                                     exit program
  rescue START END                         rescue a lost partition near START and END
  resizepart NUMBER END                    resize partition NUMBER
  rm NUMBER                                delete partition NUMBER
  select DEVICE                            choose the device to edit
  disk_set FLAG STATE                      change the FLAG on selected device
  disk_toggle [FLAG]                       toggle the state of FLAG on selected device
  set NUMBER FLAG STATE                    change the FLAG on partition NUMBER
  toggle [NUMBER [FLAG]]                   toggle the state of FLAG on partition NUMBER
  unit UNIT                                set the default unit to UNIT
  version                                  display the version number and copyright information of GNU
```

创建一个新的 GPT 硬盘标签：

```sh
mklabel gpt
```

确认格式化：

```sh
# Warning: The existing disk label on /dev/sda will be destroyed and all data on this disk will be lost. Do you want to continue?
# Yes/No? Yes
```

设置单位为 TB：

```sh
unit TB
```

创建一个占满空间的分区：
- 这里 END 设为 2 是对于 2TB 的硬盘，如果是 4TB，那么 END 值就为 4
- 或者用百分比更好
- 文件系统 `ext4` 适合 Ubuntu，`fat32` 同时适合 Ubuntu 或 Windows，所以推荐用 `fat32` 

```sh
# mkpart PART-TYPE [FS-TYPE] START END

# # ext4, 绝对大小, 2TB
# mkpart primary ext4 0 2
# # ext4, 百分比
# mkpart primary ext4 0% 100%

# # fat32, 绝对大小, 2TB
# mkpart primary fat32 0 2
# fat32, 百分比
mkpart primary fat32 0% 100%
```

查看分区结果：

```sh
print
```

输出形如：

```sh
Model: ST2000DM 001-1ER164 (scsi)
Disk /dev/sda: 2.00TB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

# 如果是 ext4
Number  Start   End     Size    File system  Name     Flags
 1      0.00TB  2.00TB  2.00TB               primary

# 如果是 fat32
Number  Start   End     Size    File system  Name     Flags
 1      0.00TB  2000GB  2.00TB  fat32        primary
```

保存并退出 parted：

```sh
quit
```

会提示你更新 `/etc/fstab`：

```sh
Information: You may need to update /etc/fstab.
```

### 格式化文件系统

查看分区后的设备名：

```sh
`sudo fdisk -l`
```

输出形如：

```sh
Disk /dev/sda: 1.82 TiB, 2000398934016 bytes, 3907029168 sectors
Disk model: 001-1ER164
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: ********-****-****-****-************

Device     Start        End    Sectors  Size Type
/dev/sda1   2048 3907028991 3907026944  1.8T Microsoft basic data
```

格式化为对应文件系统：
- <m>注意，<code>fat32</code> 对应的是 <code>vfat</code>，不是 <code>fat32</code></m>
- <m>注意，是 <code>/dev/sda1</code> 而不是 <code>/dev/sda</code></m>

```sh
# # ext4
# sudo mkfs -t ext4 /dev/sda1
# fat32
sudo mkfs -t vfat /dev/sda1
```

::: tip See: ubuntu - mount: wrong fs type, bad option, bad superblock - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/315063/mount-wrong-fs-type-bad-option-bad-superblock

13.04 - Can't mount/format internal hard drive - Ask Ubuntu
* https://askubuntu.com/questions/486858/cant-mount-format-internal-hard-drive
:::

## 挂载

### 创建挂载点

Ubuntu 默认使用 `/media` 作为挂载点。

所以我们也遵循该约定俗成，将 `/dev/sda` 挂载到 `/media/data1`。

```sh
sudo mkdir /media/data1
```

### 挂载硬盘（自动）

在 `/etc/fstab` 末尾添加如下内容：
- <m>注意，<code>fat32</code> 对应的是 <code>vfat</code>，不是 <code>fat32</code></m>
- <m>注意，是 <code>/dev/sda1</code> 而不是 <code>/dev/sda</code></m>

```sh
# # ext4
# /dev/sda1   /media/data1   ext4   defaults   0   2
# fat32
/dev/sda1   /media/data1   vfat   defaults   0   2
```

让更改生效：

```sh
sudo mount -a
```

查看硬盘容量：

```sh
df -h /media/data1
```

输出形如：

```sh
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       1.9T   32K  1.9T   1% /media/data1
```

或者查看全部硬盘容量：

```sh
df -h
```