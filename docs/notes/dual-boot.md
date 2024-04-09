# 安装 Windows 10 + Ubuntu 22.04 双系统

在已经安装了 Windows 10 的系统上，安装 Ubuntu 22.04 双系统。

## 制作启动盘

### 下载 Ubuntu 22.04 桌面版镜像

- https://cn.ubuntu.com/download/desktop
- https://releases.ubuntu.com/22.04/ubuntu-22.04.4-desktop-amd64.iso

::: See: Ubuntu 服务器版与桌面版有什么区别？
* https://linux.cn/article-14146-1.html
:::

### 下载 Rufus 启动盘工具

- https://rufus.ie/zh/
- https://github.com/pbatard/rufus/releases/download/v4.4/rufus-4.4.exe

### 制作启动盘

插入 U 盘，启动 Rufus，选择“ubuntu-22.04.4-desktop-amd64.iso”。

分区类型为 GPT，目标系统类型为 UEFI(非CSM)，文件系统为 FAT32(默认)，簇大小为 16K字节(默认)。点击“开始”。
- 如果设置错误，可能会在后面 Ubuntu 分区操作后提示“Reserved BIOS boot area partition”

::: tip See: NTFS, FAT32和exFAT文件系统有什么区别？ - 知乎
* https://zhuanlan.zhihu.com/p/32364955

> Fat32 ……可以在任何操作系统平台上使用，……缺陷是只支持最大单文件大小容量为4GB。
> 
> NTFS 是微软为硬盘或固态硬盘创建的默认新型文件系统，……最大的缺点是 Mac 系统只能读取 NTFS 文件但没有权限写入，需要借助第三方工具才能实现。因此跨平台的功能非常差。
:::

::: tip See: MBR和GPT区别是什么？
* https://www.disktool.cn/content-center/mbr-vs-gpt-1016.html

> 通常来说，MBR 和 BIOS（MBR+BIOS）、GPT 和 UEFI（GPT+UEFI）是相辅相成的。这对于某些操作系统（例如 Windows）是强制性的，但是对于其他操作系统（例如 Linux）来说是可以选择的。
:::

## 磁盘分区

### 下载傲梅分区助手
- https://www.disktool.cn/download.html
- https://www.disktool.cn/go/download/PAInstall.zip

### 分区

选择最后一个分区（如有 CD 盘则选 D 盘，CDE 盘则选 E 盘），匀出一定磁盘空间（如 200GB）给 Ubuntu，使其状态为“未分配空间”。点击“提交”。

- 这里选择最后一个分区，是因为两个系统文件格式不同，为了避免影响，尽可能保证同一文件系统的存储空间连续。
- 如果“未分配空间”后面还有别的分区（例如 WINRE_DRV），可以移动这个分区到“未分配空间”之前，提交，以保证“未分配空间”在最后。

### 关闭 Windows 快速启动

控制面板 > 硬件和声音 > 电源选项 > 更改电源按钮的功能 > 更改当前不可用的设置 > 取消勾选“启用快速启动”。

- 这一步是为了避免启动时无法识别 U 盘。

### 关闭 bitlocker

设置 > 更新和安全 > 设备加密 > 关闭。等待进度条走完即可。

- 这一步主要是在修改 Boot mode 安全设置时，可能会提示需要 bitlocker 密钥。
- 如果弹出 bitlocker 提示，可到下面网址登录账号查看密钥，密钥为短杠`-`分隔的纯数字
    - https://aka.ms/myrecoverykey

## 安装 Ubuntu 22.04

### （弃用）配置 BIOS
::: warning 该部分不再需要
:::

插上 U 盘，重启电脑，快速点按约定按键进入 BIOS（例如小新 Air 14 是 F2，不需要加 Fn）。

1. 按 → 方向键切换到 Security，选择 Secure Boot，回车后设为 Disabled；
2. 转到 Exit，把 OS Optimized Defaults 设置为 Disabled 或 Other OS；
3. 选择 Load Default Settings，回车加载设置；
    - 此时会弹框 OS Optimized Defaults，选择 Yes
    - 加载默认设置之后，部分机型需要先按 F10 保存重启，再按 F2 进入 BIOS
4. F10 保存设置

::: tip See: 联想小新Air 14笔记本怎么用U盘重装系统win7
* http://ywupe.com/jiaocheng/czwin7/37.html
:::

### 开始安装

快速点按 F12（<m>注意此时是 F12 不是 F2</m>），进入 Boot Manager 界面；
- 选择 U 盘启动：**Linpus lite: KingstonDataTraveler 3.0**）
- 回车进入 Ubuntu 安装界面：**Try or Install Ubuntu**

按照提示一路安装即可。
- 语言和键盘布局：English (US)
- 连接 WiFi（笔记本）
- 勾选：Install third-party software for graphics and Wi-Fi hardware and additional media formats
- Installation type：<m>一定要选 Something else！否则有可能覆盖原有磁盘！</m>
- 进入手动分区

### 手动分区

选中最下面的 <m>free space</m>（可以看大小判断），点击 + 号，依次设置分区如下：

| Mount point | Size               | Type           | Location                | Use as                      | 备注                                                     |
|-------------|--------------------|----------------|-------------------------|-----------------------------|----------------------------------------------------------|
| EFI         | 2 GB (2048 MB)     | Logical        | Beginning of this space | EFI System Partition        |                                                          |
| /swap       | 8 GB (8192 MB)     | Logical        | Beginning of this space | swap area                   | 通常设为物理内存的 2 倍，内存 >= 8G 时，设为固定值 8G 即可 |
| /           | 80 GB (81920 MB)   | <m>Primary</m> | Beginning of this space | Ext4 journaling File system | /root                                                    |
| /home       | 110GB (剩下都给它) | Logical        | Beginning of this space | Ext4 journaling File system | /home                                                    |

选择 Device for boot loader installation 为 EFI 分区。
- 一定要注意分区名称，在此例中，为 <m>/dev/nvme0n1p6</m>
- 之所以编号到 p6，是因为前面几个分区是 Windows 的

点击 Install Now，确认分区设置，点击 Continue。

<m>如果此时弹出“Reserved BIOS boot area partition”的提示，请立刻 Revert，然后 Quit。</m>

- 这个错误一般是前面启动盘的分区和目标系统类型错误设置成了 MBR+BIOS，正确的设置应该是 GPT+UEFI(非CSM)。
- 或者参考下面的解决方案。

::: warning See: Ubuntu installation error: Reserved BIOS boot area partition? What to do to continue installation?
- https://askubuntu.com/questions/928951/ubuntu-installation-error-reserved-bios-boot-area-partitionwhat-to-do-to-conti

> In a dual-boot setup, though, a GPT disk means that Windows is installed in EFI mode, and the request that you create a BIOS Boot Partition means that the Ubuntu installer is booted in BIOS mode, and is trying to set up a BIOS-mode boot.
:::

### 继续安装

- 选择时区：Shanghai
- 设置用户名、机器名、密码等

点击 Continue。等待安装完成。

提示 Restart now 时，拔掉 U 盘，点击重启。
- 如果提示 SQUASHFS error，强行关机，再启动，一般就没问题了。

在启动界面，选择第一行（Ubuntu）进入系统。

## 参考资料

按照有用程度排序。

* <m>【推荐】</m>windows11安装ubuntu22.04双系统教程（亲测） - 知乎
  * https://zhuanlan.zhihu.com/p/644425528

* 安装Ubuntu和win双系统（Win10ltsc+Ubuntu22.04LTS） - 哔哩哔哩
  * https://www.bilibili.com/read/cv31473459/

* 深度学习双系统搭建：Ubuntu22.04+Windows11 - 知乎
  * https://zhuanlan.zhihu.com/p/641230886

* 安装双系统win10+Ubuntu20.04LTS（详细到我自己都害怕） - 知乎
  * https://zhuanlan.zhihu.com/p/617640635