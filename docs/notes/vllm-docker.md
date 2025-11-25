# Docker 运行 vllm

::: tip Using Docker - vLLM
* https://docs.vllm.ai/en/stable/deployment/docker.html
:::

## 安装 NVIDIA Container Toolkit

参考：[安装 NVIDIA Container Toolkit](./nvidia-container.md)

## 下载模型

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

## 运行容器

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
