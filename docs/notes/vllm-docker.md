
## docker 运行 vllm

::: tip Using Docker - vLLM
* https://docs.vllm.ai/en/stable/deployment/docker.html

Installing the NVIDIA Container Toolkit — NVIDIA Container Toolkit
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

配置 production repo：

```sh
cd ~/downloads
curl -sL --proxy http://127.0.0.1:11111 https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -sL --proxy http://127.0.0.1:11111 https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
# 使用实验性 packages
sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

替换成中科大镜像源：

```sh
sudo sed -i 's#nvidia.github.io#mirrors.ustc.edu.cn#g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

更新 packages list：

```sh
sudo apt-get update
```

安装 NVIDIA Container Toolkit：

```sh
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
sudo apt-get install -y nvidia-container-toolkit=$NVIDIA_CONTAINER_TOOLKIT_VERSION nvidia-container-toolkit-base=$NVIDIA_CONTAINER_TOOLKIT_VERSION libnvidia-container-tools=$NVIDIA_CONTAINER_TOOLKIT_VERSION libnvidia-container1=$NVIDIA_CONTAINER_TOOLKIT_VERSION
```

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

重启 daemon 和 Docker 服务：

```sh
sudo systemctl daemon-reload
sudo systemctl restart docker
```

在 docker 中运行 vllm，无法使用 HF_ENDPOINT。所以先下载模型到本地：

```sh
export HF_ENDPOINT=https://hf-mirror.com
huggingface-cli download Qwen/Qwen3-0.6B
```

如果此前运行过 docker，可能会出现模型文件以 root 用户权限创建的情况，导致无法下载模型。

这时需要修改权限：

```sh
sudo chown -R "$(id -u):$(id -g)" ~/.cache/huggingface
```

然后再运行 `huggingface-cli` 下载。

在 Docker 中运行：

```sh
docker run --rm --runtime nvidia --gpus all -v ~/.cache/huggingface:/root/.cache/huggingface --env HF_ENDPOINT=https://hf-mirror.com --env HF_HUB_OFFLINE=1 --env NVIDIA_DISABLE_REQUIRE=0 -p 48989:48989 --ipc=host vllm/vllm-openai:latest --model Qwen/Qwen3-0.6B
```

- `--rm`：容器退出后删除容器
- `--runtime nvidia`：使用 NVIDIA 容器运行时
- `--gpus all`：使用所有可用的 GPU
- `-v ~/.cache/huggingface:/root/.cache/huggingface`：将本地的 Hugging Face 缓存目录挂载到容器中
- `--env HF_ENDPOINT=https://hf-mirror.com`：设置 Hugging Face
- `--env HF_HUB_OFFLINE=1`：使用本地缓存模型
- `--env NVIDIA_DISABLE_REQUIRE=1`：不检查 NVIDIA 驱动版本
- `-p 48989:48989`：将容器的 48989 端口映射到主机的 48989 端口
- `--ipc=host`：使用主机的 IPC 命名空间
- `vllm/vllm-openai:latest`：使用最新的 vllm-openai 镜像
- `--model Qwen/Qwen3-0.6B`：使用的模型
