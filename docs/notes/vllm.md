# Run LLMs locally with vllm

## Installation
```sh
pip install vllm
```

::: tip See: https://docs.vllm.ai/en/latest/getting_started/installation.html
:::

## Run API server
```sh
python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen1.5-14B-Chat-AWQ --quantization awq --host 0.0.0.0 --port 13333 --gpu-memory-utilization 0.8 --max-model-len 8192
```


::: tip See: Supported models
- https://docs.vllm.ai/en/latest/models/supported_models.html
:::