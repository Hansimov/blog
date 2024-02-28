# Run LLMs locally wtih llama-cpp

Notes for running LLM in local machine with CPU and GPUs.

All these commands are run on `Ubuntu 22.04.2 LTS`.

## Installation

### Install huggingface_hub

This is used to use `huggingface-cli` to download models.

```sh
pip install 'huggingface_hub[cli,torch]'
```

::: tip See: Installation of huggingface_hub
  - https://huggingface.co/docs/huggingface_hub/installation#install-optional-dependencies
:::

### Download models from HuggingFace

```sh
# For PRC users
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_ENABLE_HF_TRANSFER=1
```

```sh
# [Recommend] qwen1.5-14b-chat (q5_k_m)
huggingface-cli download Qwen/Qwen1.5-14B-Chat-GGUF qwen1_5-14b-chat-q5_k_m.gguf --local-dir ./models/ --local-dir-use-symlinks False

# qwen1.5-7b-chat (q2_k)
huggingface-cli download Qwen/Qwen1.5-7B-Chat-GGUF qwen1_5-7b-chat-q2_k.gguf --local-dir ./models/ --local-dir-use-symlinks False

# dolphin-2.5-mixtral-8x7b (Q5_K_M)
huggingface-cli download TheBloke/dolphin-2.5-mixtral-8x7b-GGUF dolphin-2.5-mixtral-8x7b.Q5_K_M.gguf --local-dir ./models/ --local-dir-use-symlinks False
```

::: tip See more GGUF formats of Qwen models:
  - https://huggingface.co/Qwen/Qwen1.5-14B-Chat-GGUF
  - https://huggingface.co/Qwen/Qwen1.5-7B-Chat-GGUF
:::

### Install NVIDIA CUDA Toolkit

This is to enable GPU acceleration.

```sh
# nvcc --version
sudo apt install nvidia-cuda-toolkit
```

::: tip See: How to install CUDA & cuDNN on Ubuntu 22.04
 - https://gist.github.com/denguir/b21aa66ae7fb1089655dd9de8351a202
:::

If you would like to install cuda-toolkit without root permission (e.g. in conda environment), you can use:

```sh
conda install nvidia/label/cuda-11.7.0::cuda-toolkit
```

::: tip See: https://anaconda.org/nvidia/cuda-toolkit
:::

### Install llama-cpp-python

This package is Python Bindings for llama.cpp, which enables running LLM locally with both CPU and GPUs.

```sh
LLAMA_CUBLAS=1 CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python[server]
```

If you have installed `llama-cpp-python` before setup `nvcc` correctly, you need setup `nvcc` first, then reinstall `llama-cpp-python`:

```sh
LLAMA_CUBLAS=1 CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir
```

::: tip See: README of llama-cpp-python
  - https://github.com/abetlen/llama-cpp-python/tree/main?tab=readme-ov-file#installation
:::
::: tip See: OpenAI Compatible Server of llama-cpp-python
  - https://llama-cpp-python.readthedocs.io/en/latest/server/#installation
:::

## Run Chat server

This will launch a LLM server which supports requests in OpenAI API format.

```sh
# If the machine is hosted behind proxy, 
#   you might need to unset `http(s)_proxy` before running the serive
# or set `no_proxy` as below:
export no_proxy=localhost,127.0.0.1,127.0.0.0,127.0.1.1,local.home

# If you have multiple GPUs, you can specify which one to use:
#   by default, llama-cpp will use all GPUs and allocate the memory equally
export CUDA_VISIBLE_DEVICES=0,1,2
```

```sh
# [Recommend] qwen1.5-14b-chat (q5_k_m)
python -m llama_cpp.server --model "./models/qwen1_5-14b-chat-q5_k_m.gguf" --model_alias "qwen1.5-14b-chat" --host 0.0.0.0 --port 13333 --n_ctx 8192 --n_gpu_layers 41 --interrupt_requests True

# qwen1.5-1b-chat (q2_k)
python -m llama_cpp.server --model "./models/qwen1_5-7b-chat-q5_k_m.gguf" --model_alias "qwen-1.5-7b-chat" --host 0.0.0.0 --port 13333 --n_ctx 16384 --n_gpu_layers 33 --interrupt_requests True

# dolphin-2.5-mixtral-8x7b (Q5_K_M)
python -m llama_cpp.server --model "./models/dolphin-2.5-mixtral-8x7b.Q5_K_M.gguf" --model_alias "dolphin-2.5-mixtral-8x7b" --host 0.0.0.0 --port 13333 --n_ctx 16384 --n_gpu_layers 28 --interrupt_requests True
```

```sh
# Inference on 3 * GTX 1080ti:
#   - (q5_k_m, n_ctx=8192):  [16GB VRAM, ~ 23 t/s]
#   - (q2_k,   n_ctx=1024):  [ 8GB VRAM, ~ 28 t/s]

# Inference on RTX Ada 6000:
#   - (q5_k_m, n_ctx=32768): [40GB VRAM, ~ 60 t/s]
```

You can also go to API docs to test requests interactively: `http://127.0.0.1:13333/docs`.

::: tip See: OpenAI Compatible Server in llama-cpp-python
  - https://llama-cpp-python.readthedocs.io/en/latest/server/#running-the-server
:::

### Chat with `openai` package

After the server is running, you can chat with api with following codes:

<<< @/notes/scripts/llama-cpp-with-openai.py

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/llama-cpp-with-openai.py
:::

### Options of llama-cpp server

```sh
python -m llama_cpp.server --help
```

<<< @/notes/configs/llama-cpp-options.txt

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/llama-cpp-options.txt
:::