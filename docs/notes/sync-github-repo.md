# 同步 Github 仓库到其他平台

## Huggingface

### 创建 huggingface token
* https://huggingface.co/settings/tokens

Put it in the repo secrets with name like `HF_TOKEN` in related Github repo setitngs:
* https://github.com/<user_name>/<repo_name>/settings/secrets/actions

Run following commands in the git root folder:

```sh
git remote add space https://huggingface.co/spaces/<user_name>/<repo_name>
# git remote -v
git remote set-url space https://<user_name>:<token>@huggingface.co/spaces/<user_name>/<repo_name>
git push --force space main
```

- `<repo_path>` is in the form of:
  - models: `<user_name>/<repo_name>`
  - datasets: `datasets/<user_name>/<repo_name>`
  - spaces: `spaces/<user_name>/<repo_name>`


### 使用 Github Actions 自动化
Then add a `sync_to_huggingface_space.yml` in `.github/workflows`:
* Replace the `<user_name>` (x2) and `<repo_name>` in the last line for current repo.
* The `HF_TOKEN` name should be the same with the one specified in the step above.

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/sync_to_hf.yml
:::

<<< @/notes/scripts/sync_to_hf.yml{17,18}

::: tip See: Managing Spaces with Github Actions
* https://huggingface.co/docs/hub/spaces-github-actions
:::


## Gitee

### 创建私人令牌

* https://gitee.com/profile/personal_access_tokens

### 使用 Github Actions 自动化

::: warning 注意：Gitee 仓库的`<user_name>`必须全部小写
:::

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/sync_to_gitee.yml
:::

<<< @/notes/scripts/sync_to_gitee.yml{17,18}
