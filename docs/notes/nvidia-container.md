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

## 配置 production repo

```sh
cd ~/downloads
curl -sL --proxy http://127.0.0.1:11111 https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -sL --proxy http://127.0.0.1:11111 https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
# 使用实验性 packages
sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

## 替换成中科大镜像源

```sh
sudo sed -i 's#nvidia.github.io#mirrors.ustc.edu.cn#g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

更新源索引：

```sh
sudo apt-get update
```

## 安装

```sh
# NCTV: Nvidia Container Toolkit Version
NCTV=1.18.0-1
sudo apt-get install -y nvidia-container-toolkit=$NCTV nvidia-container-toolkit-base=$NCTV libnvidia-container-tools=$NCTV libnvidia-container1=$NCTV
```

## 配置 NVIDIA Container Runtime

`sudo nano /etc/docker/daemon.json`，添加如下内容：

```json
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

重启 daemon 和 docker 服务：

```sh
sudo systemctl daemon-reload && sudo systemctl restart docker
```