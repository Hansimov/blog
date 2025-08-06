# 下载 Huggingface 文件

::: tip See: HF-Mirror - Huggingface 镜像站
* https://hf-mirror.com
:::

::: tip See: Installation of huggingface_hub
* https://huggingface.co/docs/huggingface_hub/installation#install-optional-dependencies
:::

::: tip See: Command Line Interface (CLI)
* https://huggingface.co/docs/huggingface_hub/en/guides/cli

Understand caching
* https://huggingface.co/docs/huggingface_hub/en/guides/manage-cache
:::

## 使用官方 huggingface-cli

### 安装 huggingface_hub
```sh
pip install 'huggingface_hub[cli,torch]'
export HF_ENDPOINT=https://hf-mirror.com
```

### 安装 hf_transfer（可选）

```sh
pip install hf_transfer
export HF_HUB_ENABLE_HF_TRANSFER=1
```

### 登录 hf

```sh
hf auth login
```

填写 HF_TOKEN。

### 设置镜像源

```sh
export HF_ENDPOINT=https://hf-mirror.com
```

### 下载整个仓库

```sh
hf download Qwen/Qwen-VL-Chat-Int4
```

### 下载单文件到指定位置

```sh
# Download GGUF: qwen1.5-14b-chat (q5_k_m)
hf download Qwen/Qwen1.5-14B-Chat-GGUF qwen1_5-14b-chat-q5_k_m.gguf --local-dir ./models/ --local-dir-use-symlinks False
```

### 下载某些文件

```sh
export CURRENT_MODEL="Xenova/bge-base-zh-v1.5"
hf download "$CURRENT_MODEL" --include "*.json" "*.txt" "onnx/model_int8.onnx"
```

### 查看环境变量

```sh
hf env
```

可以查看 `ENDPOINT` 环境变量是否设置为 `https://hf-mirror.com`。

### 查看本地下载模型

```sh
ls ~/.cache/huggingface/hub
```

## 使用 hfd.sh

### 安装 hfd.sh

```sh
cd ~/downloads
wget https://hf-mirror.com/hfd/hfd.sh
chmod a+x hfd.sh
```

### 下载某些文件

```sh
export HF_ENDPOINT=https://hf-mirror.com
export CURRENT_MODEL="Xenova/bge-base-zh-v1.5"
~/downloads/hfd.sh "$CURRENT_MODEL" --local-dir "/home/asimov/.cache/huggingface/hub/models--Xenova--bge-base-zh-v1.5" --include "*.json" "*.txt" "onnx/model_int8.onnx"
```

`hfd.sh` 默认会下载到当前目录，使用 `--local-dir` 可以指定下载目录。

- 这里设为 `/home/asimov/.cache/huggingface/hub/models--{org}--{repo}`，以适配官方的默认缓存目录命名。
- 注意，用户主目录 `/home/asimov` 需要写完整，否则会下载到当前 `'~'` 目录。
- 默认的 `hf download` 是用 `blobs` 和 `snapshots` 存储的，而 `hfd.sh` 是直接下载文件。
