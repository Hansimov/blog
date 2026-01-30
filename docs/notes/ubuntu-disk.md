# Ubuntu 安装新硬盘

::: tip See: InstallingANewHardDrive - Community Help Wiki
* https://help.ubuntu.com/community/InstallingANewHardDrive
:::

## 安装新 HDD 

### 查看硬盘信息

```sh
sudo lshw -C disk
```

```txt{4,8,13,23,33}
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

### 硬盘分区

如果硬盘已经格式化过并且包含数据，可以选择跳过该部分。

如果硬盘空白且未格式化，那么可以选择命令行工具或者图形界面（GParted）进行格式化。

本文选择命令行工具<f>（parted）</f>格式化。fdisk 比较老了，主要缺点是只能创建 MBR 分区。

这里以 `/dev/sda` 为例。

#### 取消挂载（可选）

如果硬盘已经挂载，需要先卸载掉：

```sh
sudo umount -l /media/data1
```

#### 使用 parted 进行分区

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

::: tip See: GPT vs MBR
- MBR<f>（Master Boot Record）</f>有两个主要限制：分区不能大于 2 TB，主分区不能超过 4 个。
- GPT<f>（GUID Partition Table）</f>没有这两个限制，但需要内核支持 EFI，一般新的发行版都是支持的。
:::


确认格式化：

```sh
# Warning: The existing disk label on /dev/sda will be destroyed and all data on this disk will be lost. Do you want to continue?
# Yes/No? Yes
```

创建一个占满空间的分区：
- 这里 END 设为 2 是对于 2TB 的硬盘，如果是 4TB，那么 END 值就为 4
- 或者用百分比更好
- 文件系统 `ext4` 适合 Ubuntu，`fat32` 同时适合 Ubuntu 或 Windows
- 推荐用 `ext4` 

```sh
# mkpart PART-TYPE [FS-TYPE] START END

# # ext4, 绝对大小, 2TB
# unit TB
# mkpart primary ext4 0 2
# # ext4, 百分比
mkpart primary ext4 0% 100%

# # fat32, 绝对大小, 2TB
# unit TB
# mkpart primary fat32 0 2
# # fat32, 百分比
# mkpart primary fat32 0% 100%
```

查看分区结果：

```sh
print
```

```txt{9,13}
Model: ST2000DM 001-1ER164 (scsi)
Disk /dev/sda: 2.00TB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

# 如果是 ext4
Number  Start   End     Size    File system  Name     Flags
 1      1049kB  2000GB  2000GB  ext4         primary

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

#### 查看分区后的设备

```sh
sudo fdisk -l
```

```txt{11,15}
Disk /dev/sda: 1.82 TiB, 2000398934016 bytes, 3907029168 sectors
Disk model: 001-1ER164
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: ********-****-****-****-************

# ext4
Device     Start        End    Sectors  Size Type
/dev/sda1   2048 3907028991 3907026944  1.8T Linux filesystem

# fat32
Device     Start        End    Sectors  Size Type
/dev/sda1   2048 3907028991 3907026944  1.8T Microsoft basic data
```

#### 格式化文件系统

- <m>注意，<code>fat32</code> 对应的是 <code>vfat</code>，不是 <code>fat32</code></m>
- <m>注意，是 <code>/dev/sda1</code> 而不是 <code>/dev/sda</code></m>

```sh
# ext4
sudo mkfs -t ext4 /dev/sda1
# # fat32
# sudo mkfs -t vfat /dev/sda1
```

::: tip See: ubuntu - mount: wrong fs type, bad option, bad superblock - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/315063/mount-wrong-fs-type-bad-option-bad-superblock

13.04 - Can't mount/format internal hard drive - Ask Ubuntu
* https://askubuntu.com/questions/486858/cant-mount-format-internal-hard-drive
:::

### 挂载

#### 创建挂载点

Ubuntu 默认使用 `/media` 作为挂载点。

所以我们也遵循该约定俗成，将 `/dev/sda` 挂载到 `/media/data1`。

```sh
sudo mkdir /media/data1
```

#### 挂载硬盘（手动）

```sh
sudo mount /dev/sda1 /media/data1
# sudo mount -a
```

#### 挂载硬盘（自动）

在 `/etc/fstab` 末尾添加如下内容：
- <m>注意，<code>fat32</code> 对应的是 <code>vfat</code>，不是 <code>fat32</code></m>
- <m>注意，是 <code>/dev/sda1</code> 而不是 <code>/dev/sda</code></m>

```sh
# # ext4
/dev/sda1   /media/data1   ext4   defaults   0   2
# # fat32
# /dev/sda1   /media/data1   vfat   defaults   0   2
```

然后执行：

```sh
sudo mount -a
```

#### 取消挂载硬盘

```sh
sudo umount /media/data1
# # if busy
# sudo umount -l /media/data1
```

#### 查看硬盘容量

```sh
df -h /media/data1
```

```txt{2}
Filesystem   Size  Used  Avail  Use%  Mounted on
/dev/sda1    1.9T   32K   1.9T    1%  /media/data1
```

或者查看全部硬盘容量：

```sh
df -h
```

## 安装新 SSD (NVMe)

### 查看硬盘信息

#### lsblk
```sh
sudo lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

或者查看指定硬盘的信息：

```sh
sudo lsblk -o NAME,MODEL,SIZE,FSTYPE,MOUNTPOINTS /dev/nvme0n1 /dev/nvme1n1
```

```txt{8-10,12-13}
NAME        MODEL                  SERIAL               SIZE TYPE FSTYPE   MOUNTPOINTS
loop0                                                     4K loop squashfs /snap/bare/5
loop1                                                  73.9M loop squashfs /snap/core22/2216
loop2                                                    74M loop squashfs /snap/core22/2292
...
sda         WDC WUH721816ALE6L4    2P*****T            14.6T disk
└─sda1                                                 14.6T part ext4     /media/data
nvme1n1     ZHITAI Ti600 4TB       ZTA604TAB********B   3.6T disk
├─nvme1n1p1                                             512M part vfat     /boot/efi
└─nvme1n1p2                                             3.6T part ext4     /var/snap/firefox/common/host-hunspell
                                                                           /
nvme0n1     ZHITAI TiPlus7100s 4TB ZTA84T0AB********0   3.7T disk
└─nvme0n1p1                                              16M part
```

这里的 `nvme0n1` 和 `nvme1n1` 就是两块 NVMe SSD。

#### 列出 /dev 设备节点

```sh
ls -l /dev/nvme*
```

```txt{2,5}
crw------- 1 root root 241,   0  1月 30 19:28 /dev/nvme0
brw-rw---- 1 root disk 259,   3  1月 30 19:28 /dev/nvme0n1
brw-rw---- 1 root disk 259,   4  1月 30 19:28 /dev/nvme0n1p1
crw------- 1 root root 241,   1  1月 30 19:28 /dev/nvme1
brw-rw---- 1 root disk 259,   0  1月 30 19:28 /dev/nvme1n1
brw-rw---- 1 root disk 259,   1  1月 30 19:28 /dev/nvme1n1p1
brw-rw---- 1 root disk 259,   2  1月 30 19:28 /dev/nvme1n1p2
crw------- 1 root root  10, 121  1月 30 19:29 /dev/nvme-fabrics
```

可以看到 `/dev/nvme0n1` 和 `/dev/nvme1n1`。

#### nvme-cli

```sh
# sudo apt install -y nvme-cli
sudo nvme list
```

```txt{3,4}
Node                  SN                   Model                    Namespace Usage                      Format           FW Rev
--------------------- -------------------- ------------------------ --------- -------------------------- ---------------- --------
/dev/nvme0n1          ZTA84T0AB********0   ZHITAI TiPlus7100s 4TB   1           4.10  TB /   4.10  TB    512   B +  0 B   ZTA25001
/dev/nvme1n1          ZTA604TAB********B   ZHITAI Ti600 4TB         1           4.00  TB /   4.00  TB    512   B +  0 B   ZTA23001
```

假设新的 SSD 是 `/dev/nvme0n1`，也即 `ZHITAI TiPlus7100s 4TB`。

#### 查看系统盘

```sh
findmnt -no SOURCE,TARGET /
```

```
/dev/nvme1n1p2 /
```

也即当前系统盘是 `/dev/nvme1n1`。

查看 `/etc/fstab`，确认系统盘的挂载信息：

```sh
cat /etc/fstab
```

### 硬盘分区

#### 清理旧分区（可选）

::: warning  一定要看清楚是哪个盘！由于安装位置不同，`nvme0n1` 和 `nvme1n1` 并不遵循先后顺序！
:::

```sh
sudo wipefs -a /dev/nvme0n1
```
```
/dev/nvme0n1: 8 bytes were erased at offset 0x00000200 (gpt): 45 46 49 20 50 41 52 54
/dev/nvme0n1: 8 bytes were erased at offset 0x3b9dca55e00 (gpt): 45 46 49 20 50 41 52 54
/dev/nvme0n1: 2 bytes were erased at offset 0x000001fe (PMBR): 55 aa
/dev/nvme0n1: calling ioctl to re-read partition table: Success
```

#### 分区 GPT

```sh
sudo parted -a optimal /dev/nvme0n1 --script mklabel gpt mkpart primary 0% 100%
```

- `-a optimal`：对齐分区以获得最佳性能
- `--script`：非交互模式
- `mklabel gpt`：创建 GPT 分区表
- `mkpart primary 0% 100%`：创建一个主分区，使用整个磁盘空间

让内核重新读取分区表：（可选，一般自动完成）

```sh
sudo partprobe /dev/nvme0n1
sudo lsblk /dev/nvme0n1
```
```
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:3    0  3.7T  0 disk
└─nvme0n1p1 259:4    0  3.7T  0 part
```

#### 格式化为 ext4

```sh
sudo mkfs.ext4 /dev/nvme0n1p1
```

### 挂载

#### 创建挂载点

假如想挂载到 `/media/ssd`：

```sh
sudo mkdir -p /media/ssd
```

#### 手动挂载

```sh
sudo mount /dev/nvme0n1p1 /media/ssd
df -hT /media/ssd
```
```
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/nvme0n1p1 ext4  3.7T   28K  3.5T   1% /media/ssd
```

#### 自动挂载

获取 UUID：

```sh
sudo blkid /dev/nvme0n1p1
```
```sh
/dev/nvme0n1p1: UUID="9e...5a" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="primary" PARTUUID="7a...e9"
```

在 `/etc/fstab` 末尾添加如下内容：

```sh
sudo nano /etc/fstab
```

```sh
# ZT NVMe SSD (4TB)
UUID=9exxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx5a  /media/ssd  ext4  defaults,noatime,nofail  0  2
```

- `UUID=9e...5a`：替换为 `blkid` 看到的实际 UUID，比用 `/dev/nvme0n1p1` 更稳定可靠
- `/media/ssd`：挂载点
- `ext4`：文件系统类型
- `defaults,noatime,nofail`：
  - `defaults`：使用默认挂载选项
  - `noatime`：访问文件时不更新访问时间，提升性能
  - `nofail`：即使这块盘挂载失败，系统也继续启动
- `0`：不进行 dump 备份，现在大部分都设为 0
- `2`：文件系统检查顺序
  - `0` 不检查，`1` 最先检查，一般只给根分区 `/`，`2` 在根分区之后检查
  - 因为这块当作数据盘，所以设为 `2`

#### 检查并挂载

```sh
sudo findmnt --verify
```
```
0 parse errors, 0 errors, 1 warning
```


```sh
sudo umount /media/ssd
sudo mount -a
```

#### 查看挂载情况

```sh
findmnt /media/ssd
```
```
TARGET     SOURCE         FSTYPE OPTIONS
/media/ssd /dev/nvme0n1p1 ext4   rw,noatime
```

```sh
mount | grep '/media/ssd'
```
```
/dev/nvme0n1p1 on /media/ssd type ext4 (rw,noatime)
```

#### 设置读写权限

让当前用户拥有该挂载点的读写权限：

```sh
sudo chown -R $USER:$USER /media/ssd
```