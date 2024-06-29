# 安装 Git

## 安装

```sh
sudo apt install git-all
```

## 配置全局用户名和邮箱

```sh
git config --global user.name "<username>"
git config --global user.email "<email>"
```

## 安装 GitHub CLI

```sh
conda install gh --channel conda-forge
```

::: tip See: cli/cli: GitHub's official command line tool
* https://github.com/cli/cli#installation
:::

## 登录

```sh
gh auth login
```

选项如下：

```sh
? What account do you want to log into? # GitHub.com
? What is your preferred protocol for Git operations on this host? # HTTPS
? Authenticate Git with your GitHub credentials? # Yes
? How would you like to authenticate GitHub CLI? # Login with a web browser
```

最后一步需要打开浏览器登录：
- https://github.com/login/device
- 输入8位一次性验证代码即可

::: tip See: Caching your GitHub credentials in Git - GitHub Docs
* https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git?platform=linux#github-cli
:::

## 配置代理

```sh
git config --global http.proxy "http://127.0.0.1:11111"
git config --global https.proxy "http://127.0.0.1:11111"
```

::: tip See: Configure Git to use a proxy
* https://gist.github.com/evantoli/f8c23a37eb3558ab8765
:::

## 安装 Git LFS

::: tip Installing Git Large File Storage - GitHub Docs
* https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage

* git-lfs/git-lfs: Git extension for versioning large files
  * https://github.com/git-lfs/git-lfs#getting-started

* git-lfs/INSTALLING.md at main · git-lfs/git-lfs
  * https://github.com/git-lfs/git-lfs/blob/main/INSTALLING.md
:::

### Ubuntu

配置包管理器：

```sh
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
```

安装 git-lfs：

```sh
sudo apt-get install git-lfs
```

查看版本：

```sh
git lfs -v
```