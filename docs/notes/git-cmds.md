# Git 常用命令

## Update local clone after remote branch name changes

```sh
git branch -m <OLD-BRANCH> <NEW-BRANCH>
git fetch origin
git branch -u origin/<NEW-BRANCH> <NEW-BRANCH>
git remote set-head origin -a
```

One-line example (change `master` to `main`):

```sh
git branch -m master main && git fetch origin && git branch -u origin/main main && git remote set-head origin -a
```

::: tip See: Renaming a branch - GitHub Docs
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/renaming-a-branch
:::


## Separate subfolder in current Git repo to a new repo

1. Create a new folder where would place the new repo
1. git clone the original repo under this folder
1. Download `git-filter-repo` from here: (Do not chagne its extension)
   * https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo
   * Place `git-filter-repo` to the cloned repo root folder
1. cd the cloned repo root folder, and run following:
   `python git-filter-repo --path <directory_to_separate_to_new_repo> --force`
1. Copy follwing files to root path of the new folder created in step 1:
   * Remaining files under `<directory_to_separate_to_new_repo>`
   * `.git` directory in original repo root folder
   * Run `git status` in the new folder root, to check the git status
   * Run `git rev-list --count main` to check the commits count of separated directory
1. `git add .`, and commit the change as a re-organizing of file structure 
1. Create new repo in Github, and get its url, then run:
   ```sh
   git remote add origin https://github.com/<owner>/<new_repo>.git
   git remote -v
   git push -u origin main
   ```

::: tip See: 将子文件夹拆分成新仓库 - GitHub 文档
* https://docs.github.com/zh/get-started/using-git/splitting-a-subfolder-out-into-a-new-repository
:::

::: tip See: Quickly rewrite git repository history (filter-branch replacement)
* https://github.com/newren/git-filter-repo
:::


## 清除 GitHub 上的僵尸提醒

::: tip Stuck with a notification for a deleted repository #174843
* https://github.com/orgs/community/discussions/174843

Bug: ghost notifications #6874
* https://github.com/orgs/community/discussions/6874#discussioncomment-14508572
:::

这种一般是因为提醒的仓库被删除了。

清除未读提醒：

```sh
gh api notifications\?all=true | jq -r 'map(select(.unread) | .id)[]' | xargs -L1 sh -c 'gh api -X PATCH notifications/threads/$0'
```

如果还想删除侧边栏里这些提醒的仓库列表：

```sh
gh api 'notifications?all=true' | jq -r '.[].id' | xargs -I {} gh api -X DELETE 'notifications/threads/{}'
```