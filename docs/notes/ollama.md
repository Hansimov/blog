# Ollama 运行本地 LLM

::: tip ollama/ollama - GitHub
- https://github.com/ollama/ollama/tree/main

Linux doc:
- https://github.com/ollama/ollama/blob/main/docs/linux.md

API doc:
- https://github.com/ollama/ollama/blob/main/docs/api.md
:::

## 下载安装 ollama

直接运行：

```sh
curl -fsSL https://ollama.com/install.sh | sh
```

如果上述命令下载缓慢，可通过代理安装：

```sh
sudo curl --proxy http://127.0.0.1:11111 -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama
sudo chmod +x /usr/bin/ollama
```

## 启动服务

```sh
ollama serve
```

指定 GPU：

```sh
CUDA_VISIBLE_DEVICES=0,1 ollama serve
```

## 下载模型

例如 qwen2 的系列模型：
- [8 GB] https://www.ollama.com/library/qwen2:7b-instruct-q8_0 

```sh
ollama pull qwen2:7b-instruct-q8_0
```
- [34 GB] https://www.ollama.com/library/qwen2:72b-instruct-q3_K_S 

```sh
ollama pull qwen2:72b-instruct-q3_K_S
```

模型默认下载到 `~/.ollama/models`。可查看硬盘使用情况：

```sh
ncdu ~/.ollama/models/blobs
```

## 运行模型

```sh
ollama run qwen2:7b-instruct-q8_0
```