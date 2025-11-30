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

## make changes in fork repo and make the commits clean

### 清理 commit 并 rebase
配置 upstream 并拉取最新代码：

```sh
git remote add upstream https://github.com/<OLD_OWNER>/<OLD_REPO>.git
git fetch upstream
```

切换到 main 分支并基于 upstream/main 进行 rebase：

```sh
git checkout main
git rebase -i upstream/main
```

### 编辑 commit 记录

在编辑器中，删除不想要的 commit：

```sh
pick aaaaaaa change message 1
pick bbbbbbb change message 2
pick ccccccc Merge branch '<OLD_OWNER>:main' into main
pick ddddddd change message 2
```

- 比如这里的 `ccccccc` 是合并 upstream/main 的 commit，可以删除这一行。

同时如果想合成一个 commit，可以把多行 `pick` 改成 `squash` 或 `s`：

```sh
pick aaaaaaa change message 1
s bbbbbbb change message 2
s ddddddd change message 2
```

`:wq` 保存退出。

如果用了 `squash`，会进入下一个编辑界面，编辑合并后的 commit message：

```sh
# This is a combination of 3 commits.
# The first commit's message is:
change message 1
# The 2nd commit's message is:
change message 2
# The 3rd commit's message is:
change message 2
```

编辑成想要的 commit message，保存退出即可。

### rebase 出现问题

如果 `git rebase -i` 的过程中出现了问题，可以回到 rebase 的当前状态：

```sh
git rebase --edit-todo
```

或者干脆放弃 rebase：

```sh
git rebase --abort
```

### 强制推送到 fork repo

强制推送到自己 fork 的 repo：

```sh
git push --force-with-lease origin main
```

### 找回误删的 commit

如果多删了 commit，可以通过 `git reflog` 找回：

```sh
git reflog
```

找到对应的 commit id，然后执行：

```sh
git checkout main
git cherry-pick <COMMIT_ID>
```

### 回到 rebase 前的状态

```sh
git reflog
```

找到 rebase 前的 commit id，然后执行：

```sh
git checkout main
git reset --hard <COMMIT_ID>
```

### 将 main 分支的改动放到 dev 分支

从 main 分支创建 dev 分支：

```sh
git checkout main
git checkout -b dev
```

将 dev 推送到远程：

```sh
git push -u origin dev
```

将 main 复位到 upstream/main：

```sh
git checkout main
git fetch upstream
git reset --hard upstream/main
git push --force-with-lease origin main
```

### 使用 main 同步上游，切换 dev 开发

同步上游 main 分支的改动到本地 main 分支，并推送到自己的 fork repo：

```sh
git checkout main
git fetch upstream
git merge --ff-only upstream/main
git push origin main
```

在 dev 分支上进行开发：

```sh
git checkout -b dev   # 或 feature/xxx
```

完成开发和改动后，推送到远程 dev 分支：

```sh
git push -u origin dev
```