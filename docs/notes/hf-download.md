# 下载 Huggingface 文件

::: tip See: HF-Mirror - Huggingface 镜像站
* https://hf-mirror.com
:::

::: tip See: Installation of huggingface_hub
* https://huggingface.co/docs/huggingface_hub/installation#install-optional-dependencies
:::

::: tip See: Command Line Interface (CLI)
* https://huggingface.co/docs/huggingface_hub/en/guides/cli
:::

## 安装 huggingface_hub
```sh
pip install 'huggingface_hub[cli,torch]'
export HF_ENDPOINT=https://hf-mirror.com
```

## 安装 hf_transfer（可选）

```sh
pip install hf_transfer
export HF_HUB_ENABLE_HF_TRANSFER=1
```

## 下载整个仓库

```sh
huggingface-cli download Qwen/Qwen-VL-Chat-Int4
```

## 下载单文件到指定位置

```sh
# Download GGUF: qwen1.5-14b-chat (q5_k_m)
huggingface-cli download Qwen/Qwen1.5-14B-Chat-GGUF qwen1_5-14b-chat-q5_k_m.gguf --local-dir ./models/ --local-dir-use-symlinks False
```


## 查看环境变量

```sh
huggingface-cli env
```

可以查看 `ENDPOINT` 环境变量是否设置为 `https://hf-mirror.com`。