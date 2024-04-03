# Sync Github Repo to Huggingface Hub

## Steps

Create a huggingface token
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


## Automate with Github Actions
Then add a `sync_to_huggingface_space.yml` in `.github/workflows`:
* Replace the `<user_name>` (x2) and `<repo_name>` in the last line for current repo.
* The `HF_TOKEN` name should be the same with the one specified in the step above.


<<< @/notes/scripts/sync_to_hf.yml{17,18}

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/sync_to_hf.yml
:::

::: tip See: Managing Spaces with Github Actions
* https://huggingface.co/docs/hub/spaces-github-actions
:::
