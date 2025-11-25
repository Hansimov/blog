# Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)

## 列出 GPU 信息

```sh
lspci | egrep -i "vga|3d|display"
```

或者：

```sh
# sudo apt-get install lshw
sudo lshw -C display
```

## 【重要】确保 Secure Boot 关闭

```sh
sudo mokutil --sb-state
```

输出应为 `SecureBoot disabled`。如果是 `SecureBoot enabled`，需要进入 BIOS 关闭。

运行：

```sh
sudo systemctl reboot --firmware-setup
```

会自动进入启动菜单界面，选择 `EFI Setup` （通常在最下面） 进入 BIOS 设置界面：
- 依次进入 `Device Manager` → `Secure Boot Configuration` → `Attempt Secure Boot`
- 将其设为 `Disabled`，也即从 `[x]` 改为 `[ ]`
- F10 保存，Esc 退出，回车确认修改设置，这样就会重启并进入系统

启动后，再在终端运行 `sudo mokutil --sb-state`，应当显示 `SecureBoot disabled`。

## 安装 NVIDIA 驱动

::: tip See: NVIDIA drivers installation | Ubuntu
- https://ubuntu.com/server/docs/nvidia-drivers-installation
:::

### 查看驱动信息

```sh
cat /proc/driver/nvidia/version
```

输出形如：

```sh
NVRM version: NVIDIA UNIX x86_64 Kernel Module  575.64.03  Wed Jun 25 18:40:52 UTC 2025
GCC version:  gcc version 12.3.0 (Ubuntu 12.3.0-1ubuntu1~22.04.2)
```

如果没安装，会提示 `No such file or directory`。


或者运行：

```sh
# sudo apt install nvidia-utils-575
nvidia-smi
```

输出形如：

```sh
Tue Sep  2 16:17:39 2025
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 575.64.03              Driver Version: 575.64.03      CUDA Version: 12.9     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   1  NVIDIA GeForce RTX 4090        Off |   00000000:41:00.0 Off |                  Off |
| 35%   35C    P8             27W /  450W |      43MiB /  49140MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```

如果安装不正确，可能会提示：

```sh
NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver.
Make sure that the latest NVIDIA driver is installed and running.
```

这个一般是驱动版本不对造成的，所以可以用下面的方法安装设备推荐的驱动。

还有一种报错是：

```sh
Failed to initialize NVML: Driver/library version mismatch...
```

这个可以试试重启解决。


### 列出推荐驱动

```sh
sudo ubuntu-drivers devices | grep recommended
```

输出形如：
```sh
# driver   : nvidia-driver-535 - distro non-free recommended
# driver   : nvidia-driver-575 - distro non-free recommended      # latest on 2025-09-02
# driver   : nvidia-driver-580 - third-party non-free recommended # latest on 2025-11-24
```

::: tip See: NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver - Stack Overflow
* https://stackoverflow.com/questions/42984743/nvidia-smi-has-failed-because-it-couldnt-communicate-with-the-nvidia-driver
:::

### 列出全部可用驱动

```sh
# desktop
sudo ubuntu-drivers list

# server
# sudo ubuntu-drivers list --gpgpu
```

例如，Ubuntu 22.04 的可用驱动输出：

```sh
nvidia-driver-535-open, (kernel modules provided by linux-modules-nvidia-535-open-generic-hwe-22.04)                                                                              [30/49]
nvidia-driver-535, (kernel modules provided by linux-modules-nvidia-535-generic-hwe-22.04)
nvidia-driver-580, (kernel modules provided by nvidia-dkms-580)
nvidia-driver-580-open, (kernel modules provided by nvidia-dkms-580-open)
nvidia-driver-575-server, (kernel modules provided by linux-modules-nvidia-575-server-generic-hwe-22.04)
nvidia-driver-575, (kernel modules provided by linux-modules-nvidia-575-generic-hwe-22.04)
nvidia-driver-535-server, (kernel modules provided by linux-modules-nvidia-535-server-generic-hwe-22.04)
nvidia-driver-575-open, (kernel modules provided by linux-modules-nvidia-575-open-generic-hwe-22.04)
...
```

### 安装驱动

更新软件包列表：

```sh
sudo apt-get update
```

* 清华源可能会有 403 Forbidden 错误
* 建议使用中科大源，详见：[Ubuntu 换国内源](./ubuntu-sources.md)

直接安装推荐的驱动：

```sh
# sudo apt install nvidia-driver-535
# sudo apt install nvidia-driver-575   # latest on 2025-09-02
sudo apt install nvidia-driver-580   # latest on 2025-11-24
```

重装：

```sh
sudo apt install --reinstall nvidia-driver-580
```

用这种方式安装可以自动安装依赖的内核模块。

也可用 `ubuntu-drivers` 安装，不过可能会有问题，目前不推荐：

```sh
# desktop: recommended
# sudo ubuntu-drivers install
# desktop: specific version
# sudo ubuntu-drivers install nvidia:535

# server: recommended
# sudo ubuntu-drivers install --gpgpu
# server: specific version
# sudo ubuntu-drivers install --gpgpu nvidia:535-server
# server: install additional components
# sudo apt install nvidia-utils-535-server
```

### 重启生效

```sh
# sudo reboot
sudo shutdown -r now
```

### 查看驱动安装是否成功

查看内核模块：

```sh
dkms status
```

输出形如：

```sh
nvidia/580.105.08, 6.8.0-40-generic, x86_64: installed
nvidia/580.105.08, 6.8.0-87-generic, x86_64: installed
```

查看模块加载：

```sh
lsmod | grep -i nvidia
```

输出形如：

```sh
nvidia_uvm           2093056  0
nvidia_drm            139264  6
nvidia_modeset       1638400  5 nvidia_drm
nvidia              104091648  71 nvidia_uvm,nvidia_modeset
video                  77824  1 nvidia_modeset
```

查看内核驱动占用：

```sh
lspci -nnk
```

输出应当包含：

```sh
kernel driver in use: ....
```

### 卸载驱动

如果版本不对，或者需要重新安装，可以先卸载已安装的驱动：

```sh
sudo apt purge "nvidia-*" && sudo apt autoremove && sudo apt autoclean
```

## 安装 CUDA (NVCC)

### 【首选】通过 NVIDIA 源安装指定版本 nvcc

::: tip CUDA Toolkit 12.9 Downloads | NVIDIA Developer
* https://developer.nvidia.com/cuda-12-9-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=22.04&target_type=deb_network
* https://developer.nvidia.com/cuda-13-0-1-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=22.04&target_type=deb_local
:::

```sh
cd ~/downloads
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
# sudo apt-get -y install cuda-toolkit-12-9
sudo apt-get -y install cuda-toolkit-13-0
```

在 `.bashrc` 或 `.zshrc` 中添加：

```sh
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

运行 `bash` 或 `zsh` 使配置生效。

### 【次选】通过 apt 安装 nvcc

```sh
sudo apt install nvidia-cuda-toolkit
```

::: tip See: How to install CUDA & cuDNN on Ubuntu 22.04
 - https://gist.github.com/denguir/b21aa66ae7fb1089655dd9de8351a202
:::

### 【次选】通过 conda 安装 nvcc

如果想在没有 root 权限的情况下安装 nvcc（比如在 conda 环境），可以运行：

```sh
conda install nvidia/label/cuda-11.7.0::cuda-toolkit
```

::: tip See: https://anaconda.org/nvidia/cuda-toolkit
:::

### 查看 CUDA 版本

```sh
which nvcc
```

* 如果是通过 NVIDIA 源安装，并且设置了环境变量，则输出为：`/usr/local/cuda/bin/nvcc`
* 如果是通过 apt 安装，则输出为：`/usr/bin/nvcc`

```sh
nvcc --version
```

::: tip See: Different CUDA versions shown by nvcc and NVIDIA-smi - Stack Overflow
* https://stackoverflow.com/questions/53422407/different-cuda-versions-shown-by-nvcc-and-nvidia-smi
:::

## 用 gpustat 查看 GPU 实时状态

安装：

```sh
pip install gpustat
```

运行：

```sh
gpustat -cpu -i
```

## 常见问题

### NVIDIA-SMI Shows ERR! on both Fan and Power Usage

> IOT instruction (core dumped)

原因是温度过高。可以尝试把显卡放到更凉快的位置，或者设置功耗限制和风扇速度。

> This issue is due to the higher temperature.
> 
> First, you should reseat the question card to the coolest location of your workstation.
> 
> Second, set the power limitation [1] and fan speed [2] to ensure the peak temperature does not exceed 75C.
> 
> [1] Change them to 150W-to-200W
> sudo nvidia-smi -pm 1
> sudo nvidia-smi -pl 150(200)
> 
> [2] https://github.com/boris-dimitrov/set_gpu_fans_public 402
> 
> Using these methods, I have restored two 1080ti cards which have the same issues.

::: tip NVIDIA-SMI Shows ERR! on both Fan and Power Usage - Graphics / Linux / Linux - NVIDIA Developer Forums
* https://forums.developer.nvidia.com/t/nvidia-smi-shows-err-on-both-fan-and-power-usage/68293/14
:::

不过也有贴子提到，更新主板 BIOS 可以解决。（待验证）

> To follow up, I solved this by upgrading my motherboard (ASUS PRIME X470-PRO) BIOS to the latest version.

::: tip RTX 4090 Fan state says "ERR!", performance is throttled - Graphics / Linux / Linux - NVIDIA Developer Forums
* https://forums.developer.nvidia.com/t/rtx-4090-fan-state-says-err-performance-is-throttled/264705/3
:::