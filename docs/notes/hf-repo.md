# 管理 Huggingface 库

::: tip Getting Started with Repositories
* https://huggingface.co/docs/hub/en/repositories-getting-started#terminal
:::

## git clone
```sh
# spaces
git clone https://huggingface.co/spaces/<user>/<repo>
# datasets
git clone https://huggingface.co/datasets/<user>/<repo>
```

## git push
git add 和 commit 的操作类似 GitHub。

### 使用 token
git push 需要用 Huggingface 的 token。进入 Huggingface 的 token 设置：
- https://huggingface.co/settings/tokens
- 添加 token（建议用 fine-grained），设好权限后复制保存
- 如果是本地操作，可以设置环境变量 `HF_TOKEN`

```sh
# spaces
git push https://<user>:$HF_TOKEN@huggingface.co/spaces/<user>/<repo> main:main
# datasets
git push https://<user>:$HF_TOKEN@huggingface.co/datasets/<user>/<repo> main:main
```

### 使用 SSH Key

访问 Huggingface 的 SSH Key 设置：
- https://huggingface.co/settings/keys

(略)
