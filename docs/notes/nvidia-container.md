# 安装 NVIDIA Container Toolkit

::: tip Installing the NVIDIA Container Toolkit — NVIDIA Container Toolkit
* https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

CUDA Installation Guide for Linux — Installation Guide for Linux 12.9 documentation
* https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

Docker Error - Unknown or Invalid Runtime Name: Nvidia · Issue #132 · NVIDIA-ISAAC-ROS/isaac_ros_visual_slam
* https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_visual_slam/issues/132

NVIDIA Container 运行时库 - USTC Mirror Help
* https://mirrors.ustc.edu.cn/help/libnvidia-container.html

Docker Error - Unknown or Invalid Runtime Name: Nvidia · Issue #132 · NVIDIA-ISAAC-ROS/isaac_ros_visual_slam
* https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_visual_slam/issues/132#issuecomment-2134831510

nvidia-container-cli reports incorrect CUDA driver version on WSL2 · Issue #148 · NVIDIA/nvidia-container-toolkit
* https://github.com/NVIDIA/nvidia-container-toolkit/issues/148#issuecomment-1811432275
:::

## 前置条件

先确认 NVIDIA 驱动和 Docker 都已经正常：

```sh
nvidia-smi
docker --version
systemctl is-active docker
```

如果 `nvidia-smi` 不能正常显示 GPU，先处理 [Ubuntu 安装 NVIDIA 驱动和 CUDA](./nvidia-driver.md)。NVIDIA Container Toolkit 不负责安装内核驱动，它只负责让 Docker 容器调用宿主机上已经可用的 NVIDIA runtime。

## 配置 repo

```sh
curl -fsSL https://mirrors.ustc.edu.cn/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://mirrors.ustc.edu.cn/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sed 's#nvidia.github.io#mirrors.ustc.edu.cn#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

如果不用中科大镜像，可以把上面的 `https://mirrors.ustc.edu.cn/libnvidia-container` 换成官方源 `https://nvidia.github.io/libnvidia-container`，并去掉第二个 `sed`。

```sh
sudo apt-get update
```

## 安装

```sh
sudo apt-get install -y nvidia-container-toolkit
```

一般不需要固定版本。只有在复现实验环境或规避已知 bug 时，才用 `apt-cache policy nvidia-container-toolkit` 查看版本并显式 pin。

## 配置 NVIDIA Container Runtime

```sh
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

`nvidia-ctk` 会合并更新 `/etc/docker/daemon.json`，比手动覆盖 `daemon.json` 更稳妥。手动编辑时不要覆盖已有的 `registry-mirrors`、代理或其他 runtime 配置。

## 检查

```sh
nvidia-container-cli info
docker info | grep -i runtime
```

如果要实际拉镜像测试，可以运行 CUDA 官方 runtime 镜像中的 `nvidia-smi`。镜像较大，网络慢时可以只做上面的 `nvidia-container-cli info` 检查。

```sh
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu22.04 nvidia-smi
```

## 和驱动/CUDA 文档的关系

- [Ubuntu 安装 NVIDIA 驱动和 CUDA](./nvidia-driver.md)：负责宿主机或 VM 内的 NVIDIA 驱动、`nvidia-smi`、CUDA Toolkit、`nvcc`。
- 本文：负责 Docker 调用已经可用的 NVIDIA 驱动。
- [安装 Docker](./docker.md)：负责 Docker Engine、Compose、镜像源、Docker daemon 代理和普通用户权限。
