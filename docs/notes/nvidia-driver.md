# Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)

## 列出 GPU 信息

```sh
sudo lshw -C display
```

## 安装 NVIDIA 驱动

::: tip See: NVIDIA drivers installation | Ubuntu
- https://ubuntu.com/server/docs/nvidia-drivers-installation
:::

### 查看驱动信息

```sh
cat /proc/driver/nvidia/version
```

如果没安装，会提示 `No such file or directory`。


或者运行：

```sh
nvidia-smi
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
driver   : nvidia-driver-535 - distro non-free recommended
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
nvidia-driver-535-server-open, (kernel modules provided by linux-modules-nvidia-535-server-open-generic-hwe-22.04)
nvidia-driver-545-open, (kernel modules provided by nvidia-dkms-545-open)
nvidia-driver-470, (kernel modules provided by linux-modules-nvidia-470-generic-hwe-22.04)
nvidia-driver-535-open, (kernel modules provided by linux-modules-nvidia-535-open-generic-hwe-22.04)
nvidia-driver-418-server, (kernel modules provided by nvidia-dkms-418-server)
nvidia-driver-535, (kernel modules provided by linux-modules-nvidia-535-generic-hwe-22.04)
nvidia-driver-450-server, (kernel modules provided by nvidia-dkms-450-server)
nvidia-driver-545, (kernel modules provided by nvidia-dkms-545)
nvidia-driver-535-server, (kernel modules provided by linux-modules-nvidia-535-server-generic-hwe-22.04)
nvidia-driver-470-server, (kernel modules provided by linux-modules-nvidia-470-server-generic-hwe-22.04)
```

### 安装驱动

直接安装推荐的驱动：

```sh
sudo apt install nvidia-driver-535
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
sudo shutdown -r now
```

### 卸载驱动

```sh
sudo apt purge "nvidia-*" && sudo apt autoremove && sudo apt autoclean
```

## 安装 CUDA

### 安装 nvcc

```sh
sudo apt install nvidia-cuda-toolkit
```

::: tip See: How to install CUDA & cuDNN on Ubuntu 22.04
 - https://gist.github.com/denguir/b21aa66ae7fb1089655dd9de8351a202
:::

如果想在没有 root 权限的情况下安装 nvcc（比如在 conda 环境），可以运行：

```sh
conda install nvidia/label/cuda-11.7.0::cuda-toolkit
```

::: tip See: https://anaconda.org/nvidia/cuda-toolkit
:::

### 查看 CUDA 版本

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