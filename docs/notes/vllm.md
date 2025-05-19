# 本地运行 vllm

::: tip Install vLLM
* https://docs.vllm.ai/en/latest/getting_started/installation/gpu.html

Engine Arguments — vLLM
* https://docs.vllm.ai/en/latest/serving/engine_args.html
:::

## 通过 pip 安装

```sh
pip install vllm
```

## 直接运行服务

```sh
vllm serve Qwen/Qwen3-1.7B --enable-reasoning --reasoning-parser deepseek_r1 --host 0.0.0.0 --port 48888 --tensor-parallel-size 2
```

### 测试

```sh
curl http://localhost:48888/v1/chat/completions -H "Content-Type: application/json" -d '{"model": "Qwen/Qwen3-1.7B","messages": [{"role": "user", "content": "来自 Hansimov 的消息：\"你是谁? 我是谁?\" 你的回答必须简短。"}], "chat_template_kwargs": {"enable_thinking": false}}' | jq
```

### 端口转发

如果该vllm服务运行在远程服务器上，要想在内网其他机器调用该服务，需要进行端口转发，比如：

```sh
ssh -p 41061 -L 48888:127.0.0.1:48888 root@11.100.0.1 -N
```

其中：
- `11.100.0.1:41061` 是远程服务器的 IP 和端口
- `48888` 是远程服务器中该 vllm 服务运行的端口
- `-p 41061` 表示连接到远程服务器的端口
- `-L 48888:127.0.0.1:48888` 表示将远程服务器的 `48888` 端口映射到本地的 `48888` 端口
- `-N` 表示不执行远程命令，只进行端口转发

## 运行 GGUF 模型

::: tip GGUF — vLLM
* https://docs.vllm.ai/en/latest/features/quantization/gguf.html

unsloth/Qwen3-32B-GGUF · Hugging Face
* https://huggingface.co/unsloth/Qwen3-32B-GGUF
:::

```sh
STORAGE="$HOME/megrez-tmp/models"
MODEL_NAME="Qwen/Qwen3-1.7B" MODEL_GGUF=Qwen3-1.7B-Q4_K_M.gguf
# MODEL_NAME="Qwen/Qwen3-4B" MODEL_GGUF=Qwen3-4B-Q4_K_M.gguf
MODEL_PATH="$STORAGE/$MODEL_GGUF"
```

```sh
MODEL_REPO="unsloth/Qwen3-1.7B-GGUF"
curl -LC - "https://hf-mirror.com/$MODLE_REPO/resolve/main/$MODEL_GGUF" -o $MODEL_PATH
```

```sh
CUDA_VISIBLE_DEVICES=0,1
```

```sh
vllm serve $MODEL_PATH --served-model-name $MODEL_NAME --tokenizer $MODEL_NAME --hf-config-path $MODEL_NAME --max-model-len 4096 --enable-reasoning --reasoning-parser deepseek_r1 --host 0.0.0.0 --port 48888 --tensor-parallel-size 2
```

### 使用 .sh 脚本

样例1：

```sh
# vllm_qwen3_1.7b.sh
export STORAGE="$HOME/megrez-tmp/models"
export MODEL_NAME="Qwen/Qwen3-1.7B"
export MODEL_GGUF="Qwen3-1.7B-Q4_K_M.gguf"
export MODEL_PATH="$STORAGE/$MODEL_GGUF"
export CUDA_VISIBLE_DEVICES=0,1
export MODEL_PORT=48888
vllm serve "$MODEL_PATH" --served-model-name $MODEL_NAME --tokenizer $MODEL_NAME --hf-config-path $MODEL_NAME --max-model-len 4096 --enable-reasoning --reasoning-parser deepseek_r1 --host 0.0.0.0 --port $MODEL_PORT --tensor-parallel-size 2
```

样例2：

```sh
# vllm_qwen3_4b.sh
export STORAGE="$HOME/megrez-tmp/models"
export MODEL_NAME="Qwen/Qwen3-4B"
export MODEL_GGUF="Qwen3-4B-Q4_K_M.gguf"
export MODEL_PATH="$STORAGE/$MODEL_GGUF"
export CUDA_VISIBLE_DEVICES=2,3
export MODEL_PORT=48889
vllm serve "$MODEL_PATH" --served-model-name $MODEL_NAME --tokenizer $MODEL_NAME --hf-config-path $MODEL_NAME --max-model-len 4096 --enable-reasoning --reasoning-parser deepseek_r1 --host 0.0.0.0 --port $MODEL_PORT --tensor-parallel-size 2
```

样例3:

```sh
# vllm_bge_large.sh
export STORAGE="$HOME/megrez-tmp/models"
export MODEL_NAME="BAAI/bge-large-zh-v1.5"
export CUDA_VISIBLE_DEVICES=2,3
export MODEL_PORT=48889
vllm serve $MODEL_NAME --served-model-name $MODEL_NAME --task embedding \
    --host 0.0.0.0 --port $MODEL_PORT \
    --tensor-parallel-size 2 --gpu-memory-utilization 0.9  --cpu-offload-gb 20 \
    --load-format auto --enable-prefix-caching --kv-cache-dtype auto \
    --max-num-batched-tokens 131072 --max-num-seqs 1024 --tokenizer-pool-size 32 \
    --disable-log-requests --disable-log-stats
```

测试：

```sh
curl http://localhost:48889/v1/embeddings -H "Content-Type: application/json" -d '{"model": "BAAI/bge-large-zh-v1.5","input": ["今天天气怎么样"]}' | jq
```

样例4: (暂时有 Bug，似乎是量化的 GGUF 的问题)

```sh
# vllm_bge_large_gguf.sh
# download model before running this script
# curl -LC - "https://hf-mirror.com/CompendiumLabs/bge-large-zh-v1.5-gguf/resolve/main/bge-large-zh-v1.5-q4_k_m.gguf" -o "$HOME/megrez-tmp/models/bge-large-zh-v1.5-q4_k_m.gguf"
export STORAGE="$HOME/megrez-tmp/models"
export MODEL_NAME="BAAI/bge-large-zh-v1.5"
export MODEL_GGUF="bge-large-zh-v1.5-q4_k_m.gguf"
export MODEL_PATH="$STORAGE/$MODEL_GGUF"
export CUDA_VISIBLE_DEVICES=2,3
export MODEL_PORT=48889
vllm serve "$MODEL_PATH" --served-model-name $MODEL_NAME --tokenizer $MODEL_NAME --hf-config-path $MODEL_NAME --task embed --enable-prefix-caching --host 0.0.0.0 --port $MODEL_PORT --tensor-parallel-size 2
```


## 通过 Python 运行服务
```sh
python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen1.5-14B-Chat-AWQ --quantization awq --host 0.0.0.0 --port 13333 --gpu-memory-utilization 0.8 --max-model-len 8192
```

::: tip See: Supported models
- https://docs.vllm.ai/en/latest/models/supported_models.html
:::