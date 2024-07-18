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

指定 GPU，并修复 qwen2 的 BUG：

```sh
OLLAMA_HOST=0.0.0.0:11434 OLLAMA_FLASH_ATTENTION=True CUDA_VISIBLE_DEVICES=0,1 ollama serve
```

`ollama serve` 可供配置的环境变量：

```sh
OLLAMA_DEBUG               Show additional debug information (e.g. OLLAMA_DEBUG=1)
OLLAMA_HOST                IP Address for the ollama server (default 127.0.0.1:11434)
OLLAMA_KEEP_ALIVE          The duration that models stay loaded in memory (default "5m")
OLLAMA_MAX_LOADED_MODELS   Maximum number of loaded models (default 1)
OLLAMA_MAX_QUEUE           Maximum number of queued requests
OLLAMA_MODELS              The path to the models directory
OLLAMA_NUM_PARALLEL        Maximum number of parallel requests (default 1)
OLLAMA_NOPRUNE             Do not prune model blobs on startup
OLLAMA_ORIGINS             A comma separated list of allowed origins
OLLAMA_TMPDIR              Location for temporary files
OLLAMA_FLASH_ATTENTION     Enabled flash attention
OLLAMA_LLM_LIBRARY         Set LLM library to bypass autodetection
OLLAMA_MAX_VRAM            Maximum VRAM
```

::: warning ollama运行qwen2：7b一直输出大写字母G · Issue #485 · QwenLM/Qwen2
  * https://github.com/QwenLM/Qwen2/issues/485
:::

## 以 API 格式调用

```sh
curl http://localhost:11434/api/chat -d '{
  "model": "llama3",
  "messages": [
    {
      "role": "user",
      "content": "why is the sky blue?"
    }
  ]
}'
```

::: tip Generate a chat completion - ollama
- https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion
:::


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