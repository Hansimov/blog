# 本地运行 Qwen-VL-Chat-Int4

::: tip See: Qwen-VL 量化
- https://github.com/QwenLM/Qwen-VL/blob/master/README_CN.md#%E9%87%8F%E5%8C%96

See: Installation of AutoGPTQ
- https://github.com/AutoGPTQ/AutoGPTQ?tab=readme-ov-file#installation

See: Run Qwen-VL-Chat-Int4 with transformers
- https://huggingface.co/Qwen/Qwen-VL-Chat-Int4#%F0%9F%A4%97-transformers
:::

## 一键安装依赖

```sh
wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/scripts/qwen_vl_setup.sh -O ./qwen_vl_setup.sh && chmod +x ./qwen_vl_setup.sh && ./qwen_vl_setup.sh
```

::: tip 脚本: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/qwen_vl_setup.sh
:::

<<< @/notes/scripts/qwen_vl_setup.sh

## 一键运行 demo

```sh
wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/scripts/qwen_vl_chat_int4.py -O ./qwen_vl_chat_int4.py
HF_ENDPOINT=https://hf-mirror.com python ./qwen_vl_chat_int4.py
```

::: tip 脚本: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/qwen_vl_chat_int4.py
:::

<<< @/notes/scripts/qwen_vl_chat_int4.py